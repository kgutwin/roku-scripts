<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="/categories">
<html>
<head>
<title>MythTV MP4 feed</title>
<link rel="stylesheet" type="text/css" href="feedstyle.css"/>
</head>
<body>
  <h1>MythTV MP4 Feed</h1>
  <xsl:apply-templates/>
</body>
</html>
</xsl:template>

<xsl:template match="category">
  <div class="category">
    <h2 class="program-title"><xsl:value-of select="@title"/></h2>
    <xsl:element name="a">
      <xsl:attribute name="href">
	<xsl:value-of select="document(categoryLeaf[@title='All']/@feed)/feed/item[1]/media[1]/streamUrl"/>
      </xsl:attribute>
      <xsl:element name="img">
	<xsl:attribute name="src">
	  <xsl:value-of select="@hd_img"/>
	</xsl:attribute>
	<xsl:attribute name="class">program-thumb</xsl:attribute>
      </xsl:element>
    </xsl:element>
    <ul>
      <xsl:apply-templates select="document(categoryLeaf[@title='All']/@feed)"/>
    </ul>
  </div>
</xsl:template>

<xsl:template match="feed/item">
  <li>
    <h3>
      <xsl:element name="a">
	<xsl:attribute name="href"><xsl:value-of select="media[1]/streamUrl"/></xsl:attribute>
	<xsl:value-of select="title"/>
      </xsl:element>
    </h3>
    <div class="info-box">
      <span class="channel"><xsl:value-of select="genres"/></span>
      <span class="quality"><xsl:value-of select="contentQuality"/></span><br />
      <span class="runtime"><xsl:value-of select="round(runtime div 60)"/>min</span>
      <span class="bitrate"><xsl:value-of select="media[1]/streamBitrate"/>kbps</span>
    </div>
    <p><xsl:value-of select="synopsis"/></p>
  </li>
</xsl:template>

</xsl:stylesheet>
