#!/usr/bin/env python

"""
- Submit example data to REVIGO server (http://revigo.irb.hr/)
- Download and run R script for creating the treemap
- Download and run R script for creating the scatterplot
Creates files:
treemap.R, treemap.csv, treemap.Rout, revigo_treemap.pdf
scatter.R, scatter.csv, scatter.Rout, revigo_scatter.pdf
"""

import sys
import argparse
import os
import urllib
import mechanize

def arg_load():
    """
        Lit les arguments et les assigne a gofile et aux options d'impression
        que sont notreemapr, notreemapcsv, noscatterr et noscattercsv
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("gofile", help="The GO\tp.value file.")
    parser.add_argument("-p", "--prefix", default='',
                        help="Prefix for all the outputs.")
    parser.add_argument("-t", "--notreemapr", action="store_true",
                        help="Boolean - output the treemap.R file.")
    parser.add_argument("-c", "--notreemapcsv", action="store_true",
                        help="Boolean - output the treemap.csv file.")
    parser.add_argument("-s", "--noscatterr", action="store_true",
                        help="Boolean - output the scatter.R file.")
    parser.add_argument("-a", "--noscattercsv", action="store_true",
                        help="Boolean - output the scatter.csv file.")
    return parser.parse_args()



if __name__ == "__main__":
    ARGUMENTS = arg_load()
    GOFILE = ARGUMENTS.gofile
    PREFIX = ARGUMENTS.prefix
    NOTREEMAPR = ARGUMENTS.notreemapr
    NOTREEMAPCSV = ARGUMENTS.notreemapcsv
    NOSCATTERR = ARGUMENTS.noscatterr
    NOSCATTERCSV = ARGUMENTS.noscattercsv

    # If prefix is not empty, add a "_" at the end.
    if PREFIX != '':
        PREFIX = PREFIX + "_"

    URL = "http://revigo.irb.hr/"

    # RobustFactory because REVIGO forms not well-formatted
    # BR = mechanize.Browser(factory=mechanize.RobustFactory())
    BR = mechanize.Browser()

    # For actual data, use open('mydata.TXT').read()
    # BR.open(os.path.join(URL, 'examples', 'example1.TXT'))
    # TXT = BR.response().read()
    TXT = open(GOFILE).read()

    # Encode and request
    DATA = {'inputGoList': TXT}
    BR.open(URL, data=urllib.urlencode(DATA))

    # Submit form
    BR.select_form(name="submitToRevigo")
    response = BR.submit()

    # Exact string match on the URL for getting the R treemap script
    BR.follow_link(url="toR_treemap.jsp?table=1")
    if NOTREEMAPR is False:
        with open(PREFIX + 'treemap.R', 'w') as f:
            f.write(BR.response().read())
        os.system('R CMD BATCH treemap.R')

    # Exact string match on the URL for getting the treemap csv results
    BR.back()
    BR.follow_link(url="export_treemap.jsp?table=1")
    if NOTREEMAPCSV is False:
        with open(PREFIX + 'treemap.csv', 'w') as f:
            f.write(BR.response().read())

    # go back and get R script for scatter
    BR.back()
    BR.follow_link(url="toR.jsp?table=1")
    if NOSCATTERR is False:
        with open(PREFIX + 'scatter.R', 'w') as f:
            f.write(BR.response().read())
            # Downloaded scatter script doesn't save PDF, so add this line
            f.write('ggsave("revigo_scatter.pdf")')
        os.system('R CMD BATCH scatter.R')

    # Exact string match on the URL for getting the scatterplot csv results
    BR.back()
    BR.follow_link(url="export.jsp?table=1")
    if NOSCATTERCSV is False:
        with open(PREFIX + 'scatter.csv', 'w') as f:
            f.write(BR.response().read())
