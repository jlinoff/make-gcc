# make-gcc
Bash script to build arbitrary versions of g++, boost and gdb.

Builds a specified version of the gcc compiler, boost library
and gdb debugger.

To use it after the installation, the LD_LIBRARY_PATH, PATH and
MANPATH variables must be set properly.

For each run a log is created in /tmp/make-gcc-2.sh-DTS.log where
DTS is the date-time stamp of the run. The log location can be
controlled by setting the LOGDIR environment variable.

Here is how its used to build gcc-6.4.0, boost-1.66.0 and gdb-8.1
in a local directory.

```bash
$ # build in ./linux-ubuntu-16.04.3-x86_64/6.4.0-1.66.0-8.1
$ ./make-gcc.sh 6.4.0 1.66.0 8.1
```

If you want to explicitly specify the output, do this.

```bash
$ ./make-gcc.sh 6.4.0 1.66.0 8.1 -o /opt/gcc
```

### Arguments

| Position | Argument      | Meaning    |
| -------: | ------------- | ---------- |
| 1        | GCC_VERSION   | The version of gcc to build. |
| 2        | BOOST_VERSION | The version of boost to build. |
| 3        | GDB_VERSION   | The version of gdb to build. |

### Options

| Short Form | Long Form       | Description |
| ---------- | --------------- | ----------- |
| -c         | --clean.        | Clean up the target directory before building. |
| -f FLAVOR  | --flavor FLAVOR | The boost C++ standard to build to. The default is c++11. |
| -h         | --help          | Help message. |
| -o DIR     | --out DIR       | Explicitly specify the output directory path. This overrides the prefix so|platform and version information are as lost |
| -p PREFIX  | --prefix PREFIX | Prefix of the build location. |
| -V         | --version.      | Print the program version and exit. |
