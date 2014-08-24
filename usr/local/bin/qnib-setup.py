#! /usr/bin/env python
# -*- coding: utf-8 -*-

""" Setup a qnib/terminal container

Usage:
    qnib-setup.py [options]
    qnib-setup.py (-h | --help)
    qnib-setup.py --version

Options:
    -h --help               Show this screen.
    --version               Show version.
    --loglevel, -L=<str>    Loglevel
                            (ERROR, CRITICAL, WARN, INFO, DEBUG)
    --log2stdout, -l        Log to stdout, otherwise to logfile.
    --logfile, -f=<path>    Logfile to log to (default: <scriptname>.log)
    --cfg, -c=<path>        Configuration file. [default: /etc/qnib-setup.cfg]

"""
from qnibsetup import QnibConfig, QnibSetup

try:
    from docopt import docopt
except ImportError:
    HAVE_DOCOPT = False
else:
    HAVE_DOCOPT = True

__author__    = 'Christian Kniep <christian()qnib.org>'
__copyright__ = 'Copyright 2014 Christian Kniep'
__license__   = """MIT License (http://opensource.org/licenses/MIT)"""


def main():
    """ main function """
    options = None
    if HAVE_DOCOPT:
        options = docopt(__doc__,  version='Test Script 0.1')
    qcfg = QnibConfig(options)
    print qcfg
    qs =QnibSetup(qcfg)
    qs.run()


if __name__ == "__main__":
    main()
