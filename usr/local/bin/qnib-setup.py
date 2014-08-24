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

# load librarys
import logging
import os
import re
import codecs
import socket
import ast
from ConfigParser import RawConfigParser, NoOptionError

try:
    from docopt import docopt
except ImportError:
    HAVE_DOCOPT = False
else:
    HAVE_DOCOPT = True

__author__    = 'Christian Kniep <christian()qnib.org>'
__copyright__ = 'Copyright 2014 Christian Kniep'
__license__   = """MIT License (http://opensource.org/licenses/MIT)"""


## Service map
SERVICE_MAP = {
    53: 'dns',
    4001: 'etcd',
    2003: 'carbon',
}

class QnibConfig(RawConfigParser):
    """ Class to abstract config and options
    """
    specials = {
            'TRUE'  : True,
            'FALSE' : False,
            'NONE'  : None,
        }
    def __init__(self, opt):
        """ init """
        RawConfigParser.__init__(self)
        if opt is None:
            self._opt = {
            }
        else:
            self._opt = opt
        
        ### Defaults
        self.logformat = '%(asctime)-15s %(levelname)-5s [%(module)s] %(message)s'
        
        ### eval if opt is set
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
        except ValueError:   # e.g. %(xxx)s in string
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
    
        if self.log2stdout:
            logging.basicConfig(level=self.loglevel,
                                format=self.logformat)
        else:
            logging.basicConfig(filename=self.logfile,
                                level=self.loglevel,
                                format=self.logformat)

    def __str__(self):
        """ print human readble """
        ret = []
        for key, val in self.__dict__.items():
            if not re.match("_.*", key):
                ret.append("%-15s: %s" % (key, val))
        return "\n".join(ret)

    def update_file(self):
        """ updates config file
        """
        with open(self.cfg, "w") as fd:
            self.write(fd)



class QnibSetup(object):
    """ Fetches the environment and act accordingly
    """

    def __init__(self, cfg):
        """ Init of instance
        """
        self._cfg = cfg
        if not self._cfg.has_option('defaults', 'docker_dns'):
            self.update_cfg('defaults', 'docker_dns', 'False')

    def update_cfg(self, sec, opt, val):
        """ update the config and write file
        """
        if self._cfg.get(sec, opt) != str(val):
            self._cfg.set(sec, opt, val)
            self._cfg.update_file()
            return True
        return False


    def run(self):
        """ main run method
        """
        self.read_local_dns_server()
        self.eval_linked_containers()

    def setup_etcd(self):
        """ setup_the etcd
        """

    def eval_dns_server(self, dns_ips):
        """ checks if given and local dns are equal

        if so, linking containers is not needed,
        it might only help out with information
        """
        do_update = False
        for ip in dns_ips:
            if self._local_dns in ("localhost", "127.0.0.1") \
            or ip == self._local_dns:
                if self.update_cfg('defaults', 'docker_dns', 'True'):
                   do_update = True
        if do_update:
            self._cfg.update_file()

    def read_local_dns_server(self):
        """ fetch the local dns IP from /etc/resolve.conf
        """
        with open("/etc/resolv.conf", "r") as fd:
            tuples = [line.split() for line in fd.readlines()]
        for key, val in tuples:
            if key == "nameserver":
                self._local_dns = val
                break

    def eval_linked_containers(self):
        """ does sth
        """
        services = {}
        keys = [var for var in os.environ.keys() if re.match("[A-Z]+_PORT_\d+_[A-Z]+_", var)]
        for key in sorted(keys):
            val = os.environ[key]
            if key.endswith("_ADDR"):
                (hostname, _, port, proto, kind) = key.split("_")
                port = int(port)
                if port in SERVICE_MAP:
                    srv_name = SERVICE_MAP[port]
                    if srv_name not in services:
                        services[srv_name] = []
                    services[srv_name].append(val)
        self.eval_dns_server(services['dns'])
        self._do_sth = False
        for srv_name, ip_list in services.items():
            self.add_service(srv_name, ip_list)
        if self._do_sth:
            self._cfg.update_file()

    def add_service(self, srv_name, ip_list):
        """ adds a service
        """
        if not self._cfg.has_section("services"):
            self._cfg.add_section("services")
        if self._cfg.has_option("services", srv_name):
            cur_list = self._cfg.get("services", srv_name).split(",")
        else:
            cur_list = []

        for ip in ip_list:
            val = ip
            if self._cfg.get('defaults', 'docker_dns') == 'True':
                val = socket.gethostbyaddr(ip)[0]
            if val not in cur_list:
                cur_list.append(val)
                self._do_sth = True
                self.update_cfg("services", srv_name, ",".join(cur_list))



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
