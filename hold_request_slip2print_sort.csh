#!/bin/tcsh -f
#The script concatenate all prepared and defined xmls for hold slips to one xml file, where hold-slips are sorted by their shelf-marks. 
#
#Should be run every morning before library staff starts to print hold requests by running Aleph print daemon (printd.exe) in GUI
#Script should be run, when Aleph daemon ue_06 is not active, according to env variable "ue_06_active_hours" set in alephe_root/aleph_start*
#   Otherwise, run this script with   -f   argument to overcome ue_06_active_hours and ue_06 running (not recommended)
#
#Makes also printing large amount of requests faster, since Aleph 22 SP 2468 modified printd.exe - a delay of 3 secs. has been inserted
#between particual prints. 
#
#The result xml file with multi hold requsests has
#   filename: {{xxx5}}0_multi_sorted_yyyymmdd.{{ext}}  where {{xxx50}} is ADM base and {{ext}} file extension after dot, the same as in original separate files
#   xml structure: <printout>
#                      <printout> <!--second time-->
#                         .... <!-- nodes from orginal separate file -->  
#                      </printout> <!--second time-->
#                      <printout> 
#                         .... 
#                      </printout>
#                      ... <!-- so on -->
#                  <printout>
#
#created by Matyas Bajger, osu.cz, 2015-01-07, revised at svkos.cz 2018-10-03
#
#
#intial parameters - set or verify them first!!
set admBase = "xxx50" #ADM base
set printDir = "$alephe_dev/$admBase/print"

#If you like, you define own xslt template name, language and form-format (NN) for multi-hold-request xml.
#    Then set following 3 variables
#Yet, it is recommended to modify the hold-request-slip template to be able to process xmls with 
#both one /printout (separate, common) and nested /printout/prinout produced by this script (multi)
#Print template, lang and format are taken from 1st file with reuqest-slip xml, so should be the all the same. 
set xslTemplateName = "hold-request-slip" #xslt template name as defined in original node <<form-name>
set xslTemplateLang = "ENG" #xslt template language as defined in original node <form-language>
set xslTemplateFormat = "00" #xslt template format as defined in original node <form-format>
set separateAfterNSlips = "100" #if set and non zero, new result multi file will be created after reaching this amount of slips/files
                               # Use to avoid creating too large xml that may cause problems in xslt transformation or printing  
set logfile = "/...../hold_request_slip2print_sort.log" #path and file where log is stored"
set admin_email = 'aleph-admin@library.xx' #errors are sent there
#end if inital parameters


set admBase = `echo "$admBase" | aleph_tr -l`
set datum=`date +%Y%m%d`
date >>$logfile
cd $printDir
set fileCounter=0
set tempFile = "$alephe_dev/$admBase/scratch/hold_request_slip2print_sort.tmp"
set tempFiles = "$alephe_dev/$admBase/scratch/hold_request_slip2print_sort.tmp*"
set counterTempFile = "$alephe_scratch/hold_request_slip2print_sort.counter"

rm -f "$tempFile"* >&/dev/null
rm -f "$counterTempFile"* >&/dev/null

#check if ue-06 is not running, which may result in colision 

#RC1 20181015 - ue_06_active_hours can be set in $alephe_root/aleph_start, then it is OK.
#    Still, is this var is set in $data_root/prof_library, it has not beeen detected by `env` , if this script is run by Aleph job_list
#    The script $data_root/prof_librar must be called first.
source "$alephe_dev/$admBase/prof_library"
#RC1 end

if ( `ps -ef | grep ue_06 | grep $admBase -i -c | bc` > 0 && `echo "$argv[*]" | grep '\-f' -c | bc` < 1 ) then
   if ( `env | grep ue_06_active_hours -c | bc` > 0 ) then
      set ueDueHours = `env | grep ue_06_active_hours | sed 's/^.*= *//'`
      set ueHoursFrom = `echo $ueDueHours | sed 's/ *-.*$//'`
      set ueHoursTo = `echo $ueDueHours | sed 's/^.*- *//'`
      if ( `echo $ueHoursFrom | awk '{print length($0);}' | bc` != 2 || `echo $ueHoursTo | awk '{print length($0);}' | bc` != 2 ) then
         echo "ERROR while reading env variable ue_06_active_hours with value: $ueDueHours  Hours shoud be in 2-digir nombers, syntax like HH-HH." | tee -a $logfile
         echo "To overcome ue_06 check, run the script with -f (force) parameter" | tee -a $logfile
         if ( "$admin_email" != '') then
            tail $logfile -n10 >$tempFile.mail
            mail -s "hold_request_slip2print_sort.csh ERROR" $admin_email < $tempFile.mail
            rm -f $$tempFile.mail
         endif
         exit
      endif
      if ( `date +%H | bc` >= $ueHoursFrom && `date +%H | bc` <= $ueHoursTo ) then
         echo "Possible colision with ue_06 daemon due tu running the script in ue_06_active_hours (env variable with value: $ueDueHours). EXITING..." | tee -a $logfile
         echo "To overcome ue_06 check, run the script with -f (force) parameter" | tee -a $logfile
         if ( "$admin_email" != '') then
            tail $logfile -n10 >$tempFile.mail
            mail -s "hold_request_slip2print_sort.csh WARNING" $admin_email < $tempFile.mail
            rm -f $$tempFile.mail
         endif
         exit
      endif
   else
      echo "Daemon ue_06 is running in $admBase, env var. ue_06_active_hours not found, cannot be checked. EXITING due to possible colisions with ue_06" | tee -a $logfile
      echo "To overcome ue_06 check, run the script with -f (force) parameter" | tee -a $logfile
      if ( "$admin_email" != '') then
         tail $logfile -n10 >$tempFile.mail
         mail -s "hold_request_slip2print_sort.csh ERROR" $admin_email < $tempFile.mail
         rm -f $$tempFile.mail
      endif
      exit
   endif
endif

if ( $separateAfterNSlips == '' ) then
   set separateAfterNSlips = '0'
endif



  set requestFiles = `find "$printDir/$admBase"* -maxdepth 1 -type f ! -name "*multi*"`
  if ( "$requestFiles" != '') then
     #getting template name, lang and format
     if ( $xslTemplateName == '') then
       set xslTemplateName = `grep -oh '<form-name>[^<]\+</form-name>' * | sed 's/<[^>]*>//g' | head -1`
     else
        set xslTemplateName=`echo $xslTemplateName | sed 's/\..*$//'`
     endif
     if ( $xslTemplateLang == '') then
       set xslTemplateLang = `grep -oh '<form-language>[^<]\+</form-language>' * | sed 's/<[^>]*>//g' | head -1`
     else
        set xslTemplateLang = `echo $xslTemplateLang | aleph_tr -u | sed 's/[^A-Z]//g'`
     endif
     if ( $xslTemplateFormat == '') then
       set xslTemplateFormat = `grep -oh '<form-format>[^<]\+</form-format>' * | sed 's/<[^>]*>//g' | head -1`
     endif

     #loop over files
     foreach fileName ( `grep -H '<form-name>hold-request-slip' $requestFiles | sed 's/:.*//' | xargs grep '<z30-call-no-key>' | sort -k2 --field-separator=: | sed 's/:.*//'`)
        set callNoKey = ` grep '<z30-call-no-key>' $fileName  | sed -e 's/<[^>]*>//g' | sed 's/ //g' `
        set fileNameExtension = `echo $fileName | sed 's/.*\.//g'`
          #RC20201123 if pickup location is different to item sublibrary, print this separately
          #  20210528 NO!! slip must be printed according to item home sublibrary, regardeless the pickup-location
  #        set subLib = ` grep '<z30-sub-library>' $fileName  | sed -e 's/<[^>]*>//g' | sed 's/ //g' `
#        set pickup = ` grep '<z37-pickup-location>' $fileName  | sed -e 's/<[^>]*>//g' | sed 's/ //g' `
#        if ( $subLib != $pickup ) then
#           set fileNameExtension = "$pickup.$fileNameExtension" #20210528
#        endif
        #RC20201123 end

        if ( -f "$counterTempFile.$fileNameExtension" ) then 
           set counterExt = `cat "$counterTempFile.$fileNameExtension" | awk '{print $1;}'`
           set counterFileExt = `cat "$counterTempFile.$fileNameExtension" | awk '{print $2;}'`
        else
           set counterExt = 1 
           set counterFileExt = 0 
        endif
        if ( $counterExt > $separateAfterNSlips ) then
           set counterExt = 0
           @ counterFileExt = $counterFileExt + 1 
        endif

        if ( $separateAfterNSlips == '0' ) then
           set tempFileName = "$tempFile.$fileNameExtension"
        else 
           set tempFileName = "$tempFile.$counterFileExt.$fileNameExtension"
        endif
        echo "adding file $fileName contents with callNo $callNoKey to a temporary file $tempFileName" | tee -a $logfile
        grep -v '^##' $fileName | sed 's/<?xml[^>]*>//' | sed 's/< *form-name *>.*<\/ *form-name *>//g' | sed 's/< *form-language *>.*<\/ *form-language *>//g' | sed 's/< *form-format *>.*<\/ *form-format *>//g' | sed 's/< *subject *>.*<\/ *subject *>//g' >>"$tempFileName"
        rm -f $fileName 
        @ fileCounter = $fileCounter + 1
        @ counterExt = $counterExt + 1
        echo "$counterExt $counterFileExt" >"$counterTempFile.$fileNameExtension"
     end
  endif

#constructing final concatenated file
if ( `ls -l "$tempFile"* | grep $ -c | bc` > 0 ) then
  foreach tmpFile ( `ls $tempFiles` )
     if ( ! -r $tmpFile ) then
        echo "TMP File $tmpFile does not exist or is not readable. ERROR" | tee -a $logfile
     else if ( -d $tmpFile ) then
        echo "TMP File $tmpFile is a directory. ERROR" | tee -a $logfile
     else
        #set fileNameExtension = `echo $tmpFile | sed 's/\.\././' | sed 's/.*\.//g'`
        set fileNameExtension = `echo $tmpFile  | sed 's/[^\.]*\.//' | sed 's/tmp\.//'`
        echo "changing TMP file $tmpFile to a result aleph-xml file: $printDir/$admBase""_multi_sorted_$datum.$fileNameExtension" | tee -a $logfile
        echo '## - XML_XSL' >"$printDir/$admBase""_multi_sorted_$datum.$fileNameExtension"
        echo '<?xml version="1.0"?>' >>"$printDir/$admBase""_multi_sorted_$datum.$fileNameExtension"
        echo '<printout>' >>"$printDir/$admBase""_multi_sorted_$datum.$fileNameExtension"
        printf "<form-name>$xslTemplateName</form-name>\n<form-language>$xslTemplateLang</form-language>\n<form-format>$xslTemplateFormat</form-format>\n<subject/>" >>"$printDir/$admBase""_multi_sorted_$datum.$fileNameExtension"
        cat  $tmpFile >>"$printDir/$admBase""_multi_sorted_$datum.$fileNameExtension"
        echo '</printout>' >>"$printDir/$admBase""_multi_sorted_$datum.$fileNameExtension"
     endif
  end
  echo "$fileCounter files/slips sorted" | tee -a $logfile
else
  echo "No temporary files $tempFiles found. Probably nothing to sort. Bye!" | tee -a $logfile
endif

rm -f "$tempFile"* >&/dev/null
rm -f "$counterTempFile"* >&/dev/null

printf "--------------------------------------------\n" >>$logfile
