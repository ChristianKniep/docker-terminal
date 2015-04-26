#! /usr/bin/env python
# -*- coding: utf-8 -*-

"""

Usage:
    watch_psutil.py [options]

Options:
    --delay <int>           Seconds delay inbetween loop runs [default: 4]
    --loop                  Loop the execution infinitely
    --carbon-host <str>     Host to send carbon stats to [default: carbon.service.consul]
Generic Options:
    --loglevel, -L=<str>    Loglevel [default: INFO]
                            (ERROR, CRITICAL, WARN, INFO, DEBUG)
    --log2stdout, -l        Log to stdout, otherwise to logfile. [default: False]
    --logfile, -f=<path>    Logfile to log to (default: <scriptname>.log)
    --cfg, -c=<path>        Configuration file.
    -h --help               Show this screen.
    --version               Show version.

"""

# load librarys
import logging
import os
import re
import time
import codecs
import ast
import sys
import psutil
import graphitesend
from os import environ
from ConfigParser import RawConfigParser, NoOptionError

try:
    from docopt import docopt
except ImportError:
    HAVE_DOCOPT = False
else:
    HAVE_DOCOPT = True

__author__ = 'Christian Kniep <christian()qnib.org>'
__copyright__ = 'Copyright 2015 QNIB Solutions'
__license__ = """GPL v2 License (http://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)"""


class QnibConfig(RawConfigParser):
    """ Class to abstract config and options
    """
    specials = {
        'TRUE': True,
        'FALSE': False,
        'NONE': None,
    }

    def __init__(self, opt):
        """ init """
        RawConfigParser.__init__(self)
        if opt is None:
            self._opt = {
                "--log2stdout": False,
                "--logfile": None,
                "--loglevel": "ERROR",
            }
        else:
            self._opt = opt
            self.logformat = '%(asctime)-15s %(levelname)-5s [%(module)s] %(message)s'
            self.loglevel = opt['--loglevel']
            self.log2stdout = opt['--log2stdout']
            if self.loglevel is None and opt.get('--cfg') is None:
                print "please specify loglevel (-L)"
                sys.exit(0)
            self.eval_cfg()

        self.eval_opt()
        self.set_logging()
        logging.info("SetUp of QnibConfig is done...")


    def do_get(self, section, key, default=None):
        """ Also lent from: https://github.com/jpmens/mqttwarn
            """
        try:
            val = self.get(section, key)
            if val.upper() in self.specials:
                return self.specials[val.upper()]
            return ast.literal_eval(val)
        except NoOptionError:
            return default
        except ValueError:  # e.g. %(xxx)s in string
            return val
        except:
            raise
            return val


    def config(self, section):
        ''' Convert a whole section's options (except the options specified
                explicitly below) into a dict, turning

                    [config:mqtt]
                    host = 'localhost'
                    username = None
                    list = [1, 'aaa', 'bbb', 4]

                into

                    {u'username': None, u'host': 'localhost', u'list': [1, 'aaa', 'bbb', 4]}

                Cannot use config.items() because I want each value to be
                retrieved with g() as above
            SOURCE: https://github.com/jpmens/mqttwarn
            '''

        d = None
        if self.has_section(section):
            d = dict((key, self.do_get(section, key))
                     for (key) in self.options(section) if key not in ['targets'])
        return d


    def eval_cfg(self):
        """ eval configuration which overrules the defaults
            """
        cfg_file = self._opt.get('--cfg')
        if cfg_file is not None:
            fd = codecs.open(cfg_file, 'r', encoding='utf-8')
            self.readfp(fd)
            fd.close()
            self.__dict__.update(self.config('defaults'))


    def eval_opt(self):
        """ Updates cfg according to options """

        def handle_logfile(val):
            """ transforms logfile argument
                """
            if val is None:
                logf = os.path.splitext(os.path.basename(__file__))[0]
                self.logfile = "%s.log" % logf.lower()
            else:
                self.logfile = val

        self._mapping = {
            '--logfile': lambda val: handle_logfile(val),
        }
        for key, val in self._opt.items():
            if key in self._mapping:
                if isinstance(self._mapping[key], str):
                    self.__dict__[self._mapping[key]] = val
                else:
                    self._mapping[key](val)
                break
            else:
                if val is None:
                    continue
                mat = re.match("\-\-(.*)", key)
                if mat:
                    self.__dict__[mat.group(1)] = val
                else:
                    logging.info("Could not find opt<>cfg mapping for '%s'" % key)


    def set_logging(self):
        """ sets the logging """
        self._logger = logging.getLogger()
        self._logger.setLevel(logging.DEBUG)
        if self.log2stdout:
            hdl = logging.StreamHandler()
            hdl.setLevel(self.loglevel)
            formatter = logging.Formatter(self.logformat)
            hdl.setFormatter(formatter)
            self._logger.addHandler(hdl)
        else:
            hdl = logging.FileHandler(self.logfile)
            hdl.setLevel(self.loglevel)
            formatter = logging.Formatter(self.logformat)
            hdl.setFormatter(formatter)
            self._logger.addHandler(hdl)


    def __str__(self):
        """ print human readble """
        ret = []
        for key, val in self.__dict__.items():
            if not re.match("_.*", key):
                ret.append("%-15s: %s" % (key, val))
        return "\n".join(ret)

    def __getitem__(self, item):
        """ return item from opt or __dict__
        :param item: key to lookup
        :return: value of key
        """
        if item in self.__dict__.keys():
            return self.__dict__[item]
        else:
            return self._opt[item]


class WatchPs(object):
    """ Class to hold the functioanlity of the script
    """

    def __init__(self, cfg):
        """ Init of instance
        """
        self._cfg = cfg
        self.cnt_gsend()

    def loop(self):
        """  loop over run
        """
        while True:
            self.run()
            time.sleep(int(self._cfg['--delay']))

    def cnt_gsend(self):
        if 'CNT_TYPE' in environ:
            pre = "psutil.%s" % environ['CNT_TYPE']
        else:
            pre = "psutil.notype"
        try:
            self._gsend = graphitesend.init(graphite_server=self._cfg['--carbon-host'], prefix=pre)
        except graphitesend.GraphiteSendException:
            time.sleep(5)
            self.con_gsend()

    def run(self):
        """ run the function
        """
        cnt = {
            "state": {},
            "user": {}
            }
        for proc in psutil.process_iter():
            try:
                pinfo = proc.as_dict(attrs=['pid', 'name', 'username'])
                pinfo['num_threads'] = proc.num_threads()
                cpu_times = proc.cpu_times()
                pinfo['cpu_user'], pinfo['cpu_system'] = cpu_times.user, cpu_times.system
                pinfo['state'] = proc.status()
                ctx_sw = proc.num_ctx_switches()
                pinfo['ctx_sw_vol'], pinfo['ctx_sw_invol'] = ctx_sw.voluntary, ctx_sw.involuntary
                pinfo['ctx_fds'] = proc.num_fds()
            except psutil.NoSuchProcess:
                pass
            except psutil.AccessDenied:
                pass
            else:
                if pinfo['username'] != "root":
                    if pinfo['username'] not in cnt['user']:
                        cnt['user'][pinfo['username']] = 0
                    cnt['user'][pinfo['username']] += 1
                if pinfo['name'] == 'bash':
                    continue
                if pinfo['name'] == 'python':
                    mat = re.match(".*/([a-zA-Z0-9\_\-]+)\.py", proc.cmdline()[1])
                    if mat:
                        pinfo['name'] = mat.group(1)
                if pinfo['name'] in ("watch_psutil", "sleep"):
                    continue
                if pinfo['state'] not in cnt['state']:
                    cnt['state'][pinfo['state']] = 0
                cnt['state'][pinfo['state']] += 1
                if pinfo['state'] != "running":
                    continue
                mkey = "%(username)s.%(name)s" % pinfo
                for key, val in pinfo.items():
                    if key in ('pid','name','username', 'state'):
                        continue
                    self._gsend.send("%s.%s" % (mkey, key), val)
                    self._cfg._logger.debug("%s.%s %s" % (mkey, key, val))
        for key, val in cnt['user'].items():
            self._gsend.send("user.%s" % key, val)
            self._cfg._logger.debug("state.%s %s" % (key, val))
        for key, val in cnt['state'].items():
            self._gsend.send("state.%s" % key, val)
            self._cfg._logger.debug("state.%s %s" % (key, val))


def main():
    """ main function """
    options = None
    if HAVE_DOCOPT:
        options = docopt(__doc__, version='Watch psutil 0.1')
    qcfg = QnibConfig(options)
    proc = WatchPs(qcfg)

    if qcfg['--loop']:
        proc.loop()
    else:
        proc.run()


if __name__ == "__main__":
    main()
