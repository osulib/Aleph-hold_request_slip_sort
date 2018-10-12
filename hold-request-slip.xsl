<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="2.0">
    <xsl:output method="xml" indent="yes" omit-xml-declaration="yes"></xsl:output>
    <!--In the following lines, you can set margins/padding that will be added to slip printig area. 
    Might be useful for top or bottom paper feed before/after print. 
    Values must be of valid CSS unit.-->
    <xsl:variable name="margin-top" select="'0'"/>
    <xsl:variable name="margin-bottom" select="'2em'"/>
    <xsl:variable name="margin-right" select="'0'"/> 
    <xsl:variable name="margin-left" select="'0'"/>
                    
                    
   <xsl:template match="/">   
   <!--html header-->
      <html>
         <head>
            <meta HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8"/>
         </head>
         <body>
            <!--template for printout(s), might simple or many-->
            <xsl:apply-templates select="printout"/>
         </body>
      </html>
   </xsl:template>
                    
                    
   <!--template for printout(s), either simple or many-->    
   <xsl:template match="printout">    
      <!--for parent "printout" with children "printout"(s) - process them-->
      <xsl:choose>
        <xsl:when test="./printout">
         <xsl:apply-templates select="printout"/>
        </xsl:when>
        <xsl:otherwise>    
        <!--insert css page-break-after to all slips except the last one-->     
        <xsl:choose>
           <xsl:when test="following-sibling::printout[1]">
              <xsl:call-template name="printSlip">
                 <xsl:with-param name="pageBreakAfter" select="'page-break-after: always;'"/>
              </xsl:call-template>
           </xsl:when>
           <xsl:otherwise>
              <xsl:call-template name="printSlip">
                 <xsl:with-param name="pageBreakAfter" select="''"/>
              </xsl:call-template>
            </xsl:otherwise>
         </xsl:choose>
        </xsl:otherwise>    
      </xsl:choose>   
    </xsl:template> 
                    
    
    <!-- template for printing slips, each per one page -->
    <xsl:template name="printSlip">
       <xsl:param name="pageBreakAfter"/>
       <xsl:variable name="divCSS">
          <xsl:value-of select="$pageBreakAfter"/>
          <xsl:if test="margin-top">padding-top: <xsl:value-of select="$margin-top"/>;</xsl:if>
          <xsl:if test="margin-bottom">padding-bottom: <xsl:value-of select="$margin-bottom"/>;</xsl:if>
          <xsl:if test="margin-left">padding-left: <xsl:value-of select="$margin-left"/>;</xsl:if>
          <xsl:if test="margin-right">padding-right: <xsl:value-of select="$margin-right"/>;</xsl:if>
       </xsl:variable>
       
       <span style="{$divCSS}">  
                            
          <!--place for xslt code for generetaing slips as it is defined in common template for one-slip files-->
          <!--INSERT YOUR CODE HERE-->
          
       
       </span>  
    </xsl:template>
</xsl:stylesheet>
