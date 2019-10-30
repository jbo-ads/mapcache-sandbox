#!/usr/bin/env python3

from pprint import pprint
from math import sqrt
import sys
import re

import argparse
parser = argparse.ArgumentParser(description='Parse Apache log files for time profiling')
parser.add_argument("--start", default=0, type=int,
                    help='Set the start time of displayed threads in s since midnight')
parser.add_argument("--stop", default=86400, type=float,
                    help='Set the stop time of displayed threads in s since midnight')
parser.add_argument("--dmin", default=0, type=float,
                    help='Set the minimum duration in μs of displayed threads')
parser.add_argument("--dmax", default=86400000000, type=int,
                    help='Set the maximum duration in μs of displayed threads')
parser.add_argument("--indent", dest='hasindent', action='store_true',
                    help='Indent output to show call graph')
parser.add_argument("--noindent", dest='hasindent', action='store_false',
                    help='Don\'t indent output')
parser.add_argument("--statfunc",
                    help='Display statistics on a specific function')
parser.add_argument("--statsub",
                    help='Display statistics on a specific subroutine')
parser.add_argument("--log", dest='log', action='store_true',
                    help='Display log entries')
parser.add_argument("--nolog", dest='log', action='store_false',
                    help='Don\'t display log entries')
parser.set_defaults(hasindent=True,log=True)
args = parser.parse_args()
statfunc = { 'n':0,'s':0,'s2':0,'min':86400000000,'max':0 }
statsub = { 'n':0,'s':0,'s2':0,'min':86400000000,'max':0 }



linepattern = ( '\[(.*?) (.*?) (.*?) (.*?):(.*?):(.*?) (.*?)\] '
                + '\[(.*?)\] '
                + '\[(.*?) (.*?):(.*?) (.*?)\] '
                + '(.*?): '
                + '(.*?) (DEBUGJBO) (.*?) ([^ ,\n]*)( )?([^ ,\n]*)?(, .*?)?' )
logbyptid = {}
for line in sys.stdin:
  try:
    s = re.match(linepattern,line).groups()
    log = {
      'time': float(s[5])+60*(int(s[4])+60*int(s[3])),
      'ptid': s[9]+':'+s[11],
      'type': s[15],
      'func': s[16],
      'sub': s[18],
    }
    if ( log['func'] == 'mapcache_handler' and log['type'] == 'BEGIN'
         and log['time'] > args.start and log['time'] < args.stop ):
      logbyptid[log['ptid']] = [ ]
    try:
      logbyptid[log['ptid']].append(log)
    except KeyError:
      pass
    else:
      seq = logbyptid[log['ptid']]
      if log['type'] == 'OUT':
        try:
          l = [ l for l in seq if l['type'] == 'IN' and l['func'] == log['func'] and l['sub'] == log['sub'] ][0]
          log['delta_us'] = int(.5+1e6*(log['time']-l['time']))
          l['delta_us'] = log['delta_us']
          l['type'] = '*IN*'
          log['type'] = '*OUT*'
          if args.statsub and log['sub'] == args.statsub:
            x = log['delta_us']
            statsub['n'] = statsub['n'] + 1
            statsub['s'] = statsub['s'] + x
            statsub['s2'] = statsub['s2'] + x*x
            if x < statsub['min']: statsub['min'] = x
            if x > statsub['max']: statsub['max'] = x
            statsub['mean'] = statsub['s'] / statsub['n']
            statsub['variance'] = statsub['s2'] / statsub['n'] - statsub['mean']*statsub['mean']
            statsub['stddev'] = sqrt(abs(statsub['variance']))
        except IndexError:
          pass
      if log['type'] == 'END':
        l = [ l for l in seq if l['type'] == 'BEGIN' and l['func'] == log['func'] ][0]
        log['delta_us'] = int(.5+1e6*(log['time']-l['time']))
        l['delta_us'] = log['delta_us']
        l['type'] = '*BEGIN*'
        log['type'] = '*END*'
        if args.statfunc and log['func'] == args.statfunc:
          x = log['delta_us']
          statfunc['n'] = statfunc['n'] + 1
          statfunc['s'] = statfunc['s'] + x
          statfunc['s2'] = statfunc['s2'] + x*x
          if x < statfunc['min']: statfunc['min'] = x
          if x > statfunc['max']: statfunc['max'] = x
          statfunc['mean'] = statfunc['s'] / statfunc['n']
          statfunc['variance'] = statfunc['s2'] / statfunc['n'] - statfunc['mean']*statfunc['mean']
          statfunc['stddev'] = sqrt(abs(statfunc['variance']))
        if log['func'] == 'mapcache_handler' and log['delta_us'] > args.dmin and log['delta_us'] < args.dmax:
          if args.log:
            print(log['ptid'],':')
          indent = 1
          for l in seq:
            try:
              delta = l['delta_us']
            except KeyError:
              delta = '-'
            k = {
              'time': l['time'],
              'delta_us': delta,
              'type': l['type'],
              'func': l['func'],
              'sub': l['sub'],
            }
            if k['type'] == '*END*': indent = indent - 1
            if k['type'] == '*OUT*': indent = indent - 1
            if args.log:
              if args.hasindent:
                print('  '*indent,k)
              else:
                print(k)
            if k['type'] == '*IN*': indent = indent + 1
            if k['type'] == '*BEGIN*': indent = indent + 1
          if args.statfunc:
            print(args.statfunc,':',statfunc)
          if args.statsub:
            print(args.statsub,':',statsub)
          if args.log:
            print('')
  except AttributeError:
    pass

