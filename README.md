# preline

A simple command-line tool that prefixes lines of program output with a timestamp or a fixed string.

## Dependencies

- Some recent version of [CHICKEN](http://call-cc.org).

## Installation

```
$ git clone git@github.com:Adellica/preline.git
$ cd preline && chicken-install -s
```

## Examples

```sh
$ preline 'echo one ; echo two >/dev/stderr ; echo three '
2015-11-04T02:54:51 start
2015-11-04T02:54:51 > one
2015-11-04T02:54:51 ! two
2015-11-04T02:54:51 > three
2015-11-04T02:54:51 exit normal 0
```

```sh
$ preline "+mike %T" ls -l
mike 02:59:32 start
mike 02:59:32 > total 8
mike 02:59:32 > -rw-r--r-- 1 mike users 161 Nov  4 03:51 file1
mike 02:59:32 > -rwxr-xr-x 1 mike users 335 Nov  3 22:35 file2
mike 02:59:32 exit normal 0
```
