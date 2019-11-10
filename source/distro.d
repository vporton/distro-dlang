// https://github.com/nir0s/distro - Copyright 2015,2016,2017 Nir Cohen
// Copyright 2019 Victor Porton
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/**
The ``distro`` package (``distro`` stands for Linux Distribution) provides
information about the Linux distribution it runs on, such as a reliable
machine-readable distro ID, or version information.
Still, there are many cases in which access to OS distribution information
is needed. See `Python issue 1322 <https://bugs.python.org/issue1322>`_ for
more information.
*/

import std.typecons;
import std.string;
import std.process : environment;
import std.path;
import std.regex;

immutable string _UNIXCONFDIR = "/etc"; //environment.get("UNIXCONFDIR", "/etc"); // FIXME
immutable string _OS_RELEASE_BASENAME = "os-release";

// Translation table for normalizing the "ID" attribute defined in os-release
// files, for use by the :func:`distro.id` method.
//
// * Key: Value as defined in the os-release file, translated to lower case,
//   with blanks translated to underscores.
//
// * Value: Normalized value.
dstring[dstring] NORMALIZED_OS_ID;

// Translation table for normalizing the "Distributor ID" attribute returned by
// the lsb_release command, for use by the :func:`distro.id` method.
//
// * Key: Value as returned by the lsb_release command, translated to lower
//   case, with blanks translated to underscores.
//
// * Value: Normalized value.
immutable dstring[dstring] NORMALIZED_LSB_ID = [
    "enterpriseenterprise": "oracle",  // Oracle Enterprise Linux
    "redhatenterpriseworkstation": "rhel",  // RHEL 6, 7 Workstation
    "redhatenterpriseserver": "rhel",  // RHEL 6, 7 Server
];

// Translation table for normalizing the distro ID derived from the file name
// of distro release files, for use by the :func:`distro.id` method.
//
// * Key: Value as derived from the file name of a distro release file,
//   translated to lower case, with blanks translated to underscores.
//
// * Value: Normalized value.
immutable dstring[dstring] NORMALIZED_DISTRO_ID = [
    "redhat": "rhel",  // RHEL 6.x, 7.x
];

// Pattern for content of distro release file (reversed)
immutable _DISTRO_RELEASE_CONTENT_REVERSED_PATTERN = regex(
    r"(?:[^)]*\)(.*)\()? *(?:STL )?([\d.+\-a-z]*\d) *(?:esaeler *)?(.+)");

// Pattern for base file name of distro release file
immutable _DISTRO_RELEASE_BASENAME_PATTERN = regex(
    r"(\w+)[-_](release|version)$");

// Base file names to be ignored when searching for distro release file
immutable _DISTRO_RELEASE_IGNORE_BASENAMES = [
    "debian_version",
    "lsb-release",
    "oem-release",
    _OS_RELEASE_BASENAME,
    "system-release"
];


/**
Return information about the current OS distribution as a tuple
``(id_name, version, codename)`` with items as follows:
* ``id_name``:  If *full_distribution_name* is false, the result of
  :func:`distro.id`. Otherwise, the result of :func:`distro.name`.
* ``version``:  The result of :func:`distro.version`.
* ``codename``:  The result of :func:`distro.codename`.
The interface of this function is compatible with the original
:py:func:`platform.linux_distribution` function, supporting a subset of
its parameters.
The data it returns may not exactly be the same, because it uses more data
sources than the original function, and that may lead to different data if
the OS distribution is not consistent across multiple data sources it
provides (there are indeed such distributions ...).
Another reason for differences is the fact that the :func:`distro.id`
method normalizes the distro ID string to a reliable machine-readable value
for a number of popular OS distributions.
*/
auto linux_distribution(bool full_distribution_name=true) {
    return _distro.linux_distribution(full_distribution_name);
}


/**
Return the distro ID of the current distribution, as a
machine-readable string.
For a number of OS distributions, the returned distro ID value is
*reliable*, in the sense that it is documented and that it does not change
across releases of the distribution.
This package maintains the following reliable distro ID values:
==============  =========================================
Distro ID       Distribution
==============  =========================================
"ubuntu"        Ubuntu
"debian"        Debian
"rhel"          RedHat Enterprise Linux
"centos"        CentOS
"fedora"        Fedora
"sles"          SUSE Linux Enterprise Server
"opensuse"      openSUSE
"amazon"        Amazon Linux
"arch"          Arch Linux
"cloudlinux"    CloudLinux OS
"exherbo"       Exherbo Linux
"gentoo"        GenToo Linux
"ibm_powerkvm"  IBM PowerKVM
"kvmibm"        KVM for IBM z Systems
"linuxmint"     Linux Mint
"mageia"        Mageia
"mandriva"      Mandriva Linux
"parallels"     Parallels
"pidora"        Pidora
"raspbian"      Raspbian
"oracle"        Oracle Linux (and Oracle Enterprise Linux)
"scientific"    Scientific Linux
"slackware"     Slackware
"xenserver"     XenServer
"openbsd"       OpenBSD
"netbsd"        NetBSD
"freebsd"       FreeBSD
==============  =========================================
If you have a need to get distros for reliable IDs added into this set,
or if you find that the :func:`distro.id` function returns a different
distro ID for one of the listed distros, please create an issue in the
`distro issue tracker`_.
**Lookup hierarchy and transformations:**
First, the ID is obtained from the following sources, in the specified
order. The first available and non-empty value is used:
* the value of the "ID" attribute of the os-release file,
* the value of the "Distributor ID" attribute returned by the lsb_release
  command,
* the first part of the file name of the distro release file,
The so determined ID value then passes the following transformations,
before it is returned by this method:
* it is translated to lower case,
* blanks (which should not be there anyway) are translated to underscores,
* a normalization of the ID is performed, based upon
  `normalization tables`_. The purpose of this normalization is to ensure
  that the ID is as reliable as possible, even across incompatible changes
  in the OS distributions. A common reason for an incompatible change is
  the addition of an os-release file, or the addition of the lsb_release
  command, with ID values that differ from what was previously determined
  from the distro release file name.
*/
dstring id() {
    return _distro.id();
}


/**
Return the name of the current OS distribution, as a human-readable
string.
If *pretty* is false, the name is returned without version or codename.
(e.g. "CentOS Linux")
If *pretty* is true, the version and codename are appended.
(e.g. "CentOS Linux 7.1.1503 (Core)")
**Lookup hierarchy:**
The name is obtained from the following sources, in the specified order.
The first available and non-empty value is used:
* If *pretty* is false:
  - the value of the "NAME" attribute of the os-release file,
  - the value of the "Distributor ID" attribute returned by the lsb_release
    command,
  - the value of the "<name>" field of the distro release file.
* If *pretty* is true:
  - the value of the "PRETTY_NAME" attribute of the os-release file,
  - the value of the "Description" attribute returned by the lsb_release
    command,
  - the value of the "<name>" field of the distro release file, appended
    with the value of the pretty version ("<version_id>" and "<codename>"
    fields) of the distro release file, if available.
*/
dstring name(bool pretty=false) {
    return _distro.name(pretty);
}


/**
Return the version of the current OS distribution, as a human-readable
dstring.
If *pretty* is false, the version is returned without codename (e.g.
"7.0").
If *pretty* is true, the codename in parenthesis is appended, if the
codename is non-empty (e.g. "7.0 (Maipo)").
Some distributions provide version numbers with different precisions in
the different sources of distribution information. Examining the different
sources in a fixed priority order does not always yield the most precise
version (e.g. for Debian 8.2, or CentOS 7.1).
The *best* parameter can be used to control the approach for the returned
version:
If *best* is false, the first non-empty version number in priority order of
the examined sources is returned.
If *best* is true, the most precise version number out of all examined
sources is returned.
**Lookup hierarchy:**
In all cases, the version number is obtained from the following sources.
If *best* is false, this order represents the priority order:
* the value of the "VERSION_ID" attribute of the os-release file,
* the value of the "Release" attribute returned by the lsb_release
  command,
* the version number parsed from the "<version_id>" field of the first line
  of the distro release file,
* the version number parsed from the "PRETTY_NAME" attribute of the
  os-release file, if it follows the format of the distro release files.
* the version number parsed from the "Description" attribute returned by
  the lsb_release command, if it follows the format of the distro release
  files.
*/
dstring version_(bool pretty=false, bool best=false) {
    return _distro.version_(pretty, best);
}

/**
Return the version of the current OS distribution as a tuple
``(major, minor, build_number)`` with items as follows:
* ``major``:  The result of :func:`distro.major_version`.
* ``minor``:  The result of :func:`distro.minor_version`.
* ``build_number``:  The result of :func:`distro.build_number`.
For a description of the *best* parameter, see the :func:`distro.version`
method.
*/
auto version_parts(bool best=false) {
    return _distro.version_parts(best);
}


/**
Return the major version of the current OS distribution, as a string,
if provided.
Otherwise, the empty string is returned. The major version is the first
part of the dot-separated version string.
For a description of the *best* parameter, see the :func:`distro.version`
method.
*/
dstring major_version(bool best=false) {
    return _distro.major_version(best);
}

/**
Return the minor version of the current OS distribution, as a string,
if provided.
Otherwise, the empty string is returned. The minor version is the second
part of the dot-separated version string.
For a description of the *best* parameter, see the :func:`distro.version`
method.
*/
dstring minor_version(bool best=false) {
    return _distro.minor_version(best);
}

/**
Return the build number of the current OS distribution, as a string,
if provided.
Otherwise, the empty string is returned. The build number is the third part
of the dot-separated version string.
For a description of the *best* parameter, see the :func:`distro.version`
method.
*/
dstring build_number(bool best=false) {
    return _distro.build_number(best);
}

/**
Return a space-separated list of distro IDs of distributions that are
closely related to the current OS distribution in regards to packaging
and programming interfaces, for example distributions the current
distribution is a derivative from.
**Lookup hierarchy:**
This information item is only provided by the os-release file.
For details, see the description of the "ID_LIKE" attribute in the
`os-release man page
<http://www.freedesktop.org/software/systemd/man/os-release.html>`_.
*/
dstring like() {
    return _distro.like();
}

/**
Return the codename for the release of the current OS distribution,
as a string.
If the distribution does not have a codename, an empty string is returned.
Note that the returned codename is not always really a codename. For
example, openSUSE returns "x86_64". This function does not handle such
cases in any special way and just returns the string it finds, if any.
**Lookup hierarchy:**
* the codename within the "VERSION" attribute of the os-release file, if
  provided,
* the value of the "Codename" attribute returned by the lsb_release
  command,
* the value of the "<codename>" field of the distro release file.
*/
dstring codename() {
    return _distro.codename();
}

/**
Return certain machine-readable information items about the current OS
distribution in a dictionary, as shown in the following example:
.. sourcecode:: python
    {
        'id': 'rhel',
        'version': '7.0',
        'version_parts': {
            'major': '7',
            'minor': '0',
            'build_number': ''
        },
        'like': 'fedora',
        'codename': 'Maipo'
    }
The dictionary structure and keys are always the same, regardless of which
information items are available in the underlying data sources. The values
for the various keys are as follows:
* ``id``:  The result of :func:`distro.id`.
* ``version``:  The result of :func:`distro.version`.
* ``version_parts -> major``:  The result of :func:`distro.major_version`.
* ``version_parts -> minor``:  The result of :func:`distro.minor_version`.
* ``version_parts -> build_number``:  The result of
  :func:`distro.build_number`.
* ``like``:  The result of :func:`distro.like`.
* ``codename``:  The result of :func:`distro.codename`.
For a description of the *pretty* and *best* parameters, see the
:func:`distro.version` method.
*/
auto info(bool pretty=false, bool best=false) {
    return _distro.info(pretty, best);
}

/**
Return a dictionary containing key-value pairs for the information items
from the os-release file data source of the current OS distribution.
See `os-release file`_ for details about these information items.
*/
dstring[dstring] os_release_info() {
    return _distro.os_release_info();
}

/**
Return a dictionary containing key-value pairs for the information items
from the lsb_release command data source of the current OS distribution.
See `lsb_release command output`_ for details about these information
items.
*/
dstring[dstring] lsb_release_info() {
    return _distro.lsb_release_info();
}

/**
Return a dictionary containing key-value pairs for the information items
from the distro release file data source of the current OS distribution.
See `distro release file`_ for details about these information items.
*/
dstring[dstring] distro_release_info() {
    return _distro.distro_release_info();
}

/**
Return a dictionary containing key-value pairs for the information items
from the distro release file data source of the current OS distribution.
*/
dstring[dstring] uname_info() {
    return _distro.uname_info();
}

/**
Return a single named information item from the os-release file data source
of the current OS distribution.
Parameters:
* ``attribute`` (string): Key of the information item.
Returns:
* (string): Value of the information item, if the item exists.
  The empty string, if the item does not exist.
See `os-release file`_ for details about these information items.
*/
dstring os_release_attr(string attribute) {
    return _distro.os_release_attr(attribute);
}

/**
Return a single named information item from the lsb_release command output
data source of the current OS distribution.
Parameters:
* ``attribute`` (string): Key of the information item.
Returns:
* (string): Value of the information item, if the item exists.
  The empty string, if the item does not exist.
See `lsb_release command output`_ for details about these information
items.
*/
dstring lsb_release_attr(dstring attribute) {
    return _distro.lsb_release_attr(attribute);
}

/**
Return a single named information item from the distro release file
data source of the current OS distribution.
Parameters:
* ``attribute`` (string): Key of the information item.
Returns:
* (string): Value of the information item, if the item exists.
  The empty string, if the item does not exist.
See `distro release file`_ for details about these information items.
*/
dstring distro_release_attr(dstring attribute) {
    return _distro.distro_release_attr(attribute);
}

/**
Return a single named information item from the distro release file
data source of the current OS distribution.
Parameters:
* ``attribute`` (string): Key of the information item.
Returns:
* (string): Value of the information item, if the item exists.
            The empty string, if the item does not exist.
*/
dstring uname_attr(dstring attribute) {
    return _distro.uname_attr(attribute);
}

/**
The following code makes cached (memoized) property `f`
```
class {
    @property string _f() { ... }
    mixin mixin Cached!"f";
}
```
*/
mixin template Cached(string name, string baseName = '_' ~ name) {
    mixin("private typeof(" ~ baseName ~ ") " ~ name ~ "Cache;");
    mixin("private bool " ~ name ~ "IsCached = false;");
    mixin("@property typeof(" ~ baseName ~ ") " ~ name ~ "() {\n" ~
          "if (" ~ name ~ "IsCached" ~ ") return " ~ name ~ "Cache;\n" ~
          name ~ "IsCached = true;\n" ~
          "return " ~ name ~ "Cache = " ~ baseName ~ ";\n" ~
          '}');
}

/**
Provides information about a OS distribution.
This package creates a private module-global instance of this class with
default initialization arguments, that is used by the
`consolidated accessor functions`_ and `single source accessor functions`_.
By using default initialization arguments, that module-global instance
returns data about the current OS distribution (i.e. the distro this
package runs on).
Normally, it is not necessary to create additional instances of this class.
However, in situations where control is needed over the exact data sources
that are used, instances of this class can be created with a specific
distro release file, or a specific os-release file, or without invoking the
lsb_release command.
*/
struct LinuxDistribution {
private:
        string os_release_file;
        string distro_release_file; // updated later
        bool include_lsb;
        bool include_uname;

public:
    /**
    The initialization method of this class gathers information from the
    available data sources, and stores that in private instance attributes.
    Subsequent access to the information items uses these private instance
    attributes, so that the data sources are read only once.
    Parameters:
    * ``include_lsb`` (bool): Controls whether the
      `lsb_release command output`_ is included as a data source.
      If the lsb_release command is not available in the program execution
      path, the data source for the lsb_release command will be empty.
    * ``os_release_file`` (string): The path name of the
      `os-release file`_ that is to be used as a data source.
      An empty string (the default) will cause the default path name to
      be used (see `os-release file`_ for details).
      If the specified or defaulted os-release file does not exist, the
      data source for the os-release file will be empty.
    * ``distro_release_file`` (string): The path name of the
      `distro release file`_ that is to be used as a data source.
      An empty string (the default) will cause a default search algorithm
      to be used (see `distro release file`_ for details).
      If the specified distro release file does not exist, or if no default
      distro release file can be found, the data source for the distro
      release file will be empty.
    * ``include_name`` (bool): Controls whether uname command output is
      included as a data source. If the uname command is not available in
      the program execution path the data source for the uname command will
      be empty.
    Public instance attributes:
    * ``os_release_file`` (string): The path name of the
      `os-release file`_ that is actually used as a data source. The
      empty string if no distro release file is used as a data source.
    * ``distro_release_file`` (string): The path name of the
      `distro release file`_ that is actually used as a data source. The
      empty string if no distro release file is used as a data source.
    * ``include_lsb`` (bool): The result of the ``include_lsb`` parameter.
      This controls whether the lsb information will be loaded.
    * ``include_uname`` (bool): The result of the ``include_uname``
      parameter. This controls whether the uname information will
      be loaded.
    Raises:
    * :py:exc:`IOError`: Some I/O issue with an os-release file or distro
      release file.
    * :py:exc:`subprocess.CalledProcessError`: The lsb_release command had
      some issue (other than not being available in the program execution
      path).
    * :py:exc:`UnicodeError`: A data source has unexpected characters or
      uses an unexpected encoding.
    */
    static LinuxDistribution create(bool include_lsb=true,
                                    string os_release_file="",
                                    string distro_release_file="",
                                    bool include_uname=true)
    {
        LinuxDistribution d;

        d.os_release_file = os_release_file != "" ? os_release_file :
            buildPath(_UNIXCONFDIR, _OS_RELEASE_BASENAME);
        d.distro_release_file = distro_release_file; // updated later
        d.include_lsb = include_lsb;
        d.include_uname = include_uname;

        return d;
    }

    /**
    Return repr of all info
    */
    dstring toString() {
        return
            "LinuxDistribution%(" ~
            "os_release_file=%s, " ~
            "distro_release_file=%s, " ~
            "include_lsb=%s, " ~
            "include_uname=%s, " ~
            "_os_release_info=%s, " ~
            "_lsb_release_info=%s, " ~
            "_distro_release_info=%s, " ~
            "_uname_info=%s)".format(
                os_release_file,
                distro_release_file,
                include_lsb,
                include_uname,
                _os_release_info,
                _lsb_release_info,
                _distro_release_info,
                _uname_info);
    }

    /**
    Return information about the OS distribution that is compatible
    with Python's :func:`platform.linux_distribution`, supporting a subset
    of its parameters.
    For details, see :func:`distro.linux_distribution`.
    */
    auto linux_distribution(bool full_distribution_name=true) {
        return tuple(
            full_distribution_name ? name : id,
            version_,
            codename
        );
    }

    /**
    Return the distro ID of the OS distribution, as a string.
    For details, see :func:`distro.id`.
    */
    dstring id() {
        dstring normalize(const dstring distro_id, const dstring[dstring] table) {
            immutable dstring distro_id2 = distro_id.toLower.replace(' ', '_');
            return table.get(distro_id2, distro_id2);
        }

        dstring distro_id;

        distro_id = os_release_attr("id");
        if (distro_id)
            return normalize(distro_id, NORMALIZED_OS_ID);

        distro_id = lsb_release_attr("distributor_id");
        if (distro_id)
            return normalize(distro_id, NORMALIZED_LSB_ID);

        distro_id = distro_release_attr("id");
        if (distro_id)
            return normalize(distro_id, NORMALIZED_DISTRO_ID);

        distro_id = uname_attr("id");
        if (distro_id)
            return normalize(distro_id, NORMALIZED_DISTRO_ID);

        return "";
    }

    /**
    Return the name of the OS distribution, as a string.
    For details, see :func:`distro.name`.
    */
    dstring name(bool pretty=false) {
        dstring name;
        name = os_release_attr("name");
        if (name.empty) {
            name = lsb_release_attr("distributor_id");
            if (name.empty) {
                name = distro_release_attr("name");
                if (name.empty) {
                    name = uname_attr("name");
                }
            }
        }
        if (pretty) {
            name = os_release_attr("pretty_name");
            if (name.empty) {
                name = lsb_release_attr("description");
            }
            if (name.empty) {
                name = distro_release_attr("name");
                if (name.empty) {
                    name = uname_attr("name");
                }
                immutable version_ = this.version_(true);
                if (version_)
                    name = name ~ ' ' ~ version_;
            }
        }
        return name;
    }

    /**
    Return the version of the OS distribution, as a string.
    For details, see :func:`distro.version`.
    */
    dstring version_(bool pretty=false, bool best=false) {
        auto versions = [
            os_release_attr("version_id"),
            lsb_release_attr("release"),
            distro_release_attr("version_id"),
            _parse_distro_release_content(
                os_release_attr("pretty_name")).get("version_id", ""),
            _parse_distro_release_content(
                lsb_release_attr("description")).get("version_id", ""),
            uname_attr("release"),
        ];
        dstring version_;
        if (best) {
            // This algorithm uses the last version in priority order that has
            // the best precision. If the versions are not in conflict, that
            // does not matter; otherwise, using the last one instead of the
            // first one might be considered a surprise.
            foreach (v; versions) {
                if (v.count('.') > version_.count('.') || version_.empty)
                    version_ = v;
            }
        } else {
            foreach (v; versions) {
                if (!v.empty) {
                    version_ = v;
                    break;
                }
            }
        }
        if (pretty && !version_.empty && !codename.empty)
            version_ = "%s (%s)"d.format(version_, codename);
        return version_;
    }

    /**
    Return the version of the OS distribution, as a tuple of version
    numbers.
    For details, see :func:`distro.version_parts`.
    */
    auto version_parts(bool best=false) {
        immutable dstring version_str = version_(false, best);
        if (!version_str.empty) {
            auto version_regex = regex(r"(\d+)\.?(\d+)?\.?(\d+)?");
            auto matches = version_str.matchAll(version_regex);
            if (matches) {
                // can be simplified using https://bitbucket.org/infognition/dstuff/src or https://code.dlang.org/packages/vest
                dstring major = matches.front.hit;
                matches.popFront();
                dstring minor = matches.front.hit;
                matches.popFront();
                dstring build_number = matches.front.hit;
                //matches.popFront();
                return tuple(major, minor, build_number);
            }
        }
        return tuple("", "", "");
    }

    /**
    Return the major version number of the current distribution.
    For details, see :func:`distro.major_version`.
    */
    dstring major_version(bool best=false) {
        return version_parts(best)[0];
    }

    /**
    Return the minor version number of the current distribution.
    For details, see :func:`distro.minor_version`.
    */
    dstring minor_version(bool best=false) {
        return version_parts(best)[1];
    }

    /**
    Return the build number of the current distribution.
    For details, see :func:`distro.build_number`.
    */
    dstring build_number(bool best=false) {
        return version_parts(best)[2];
    }

    /**
    Return the IDs of distributions that are like the OS distribution.
    For details, see :func:`distro.like`.
    */
    dstring like() {
        return os_release_attr("id_like");
    }

    /**
    Return the codename of the OS distribution.
    For details, see :func:`distro.codename`.
    */
    dstring codename() {
        dstring codename;
        codename = os_release_attr("codename");
        if (!codename.empty) return codename;
        codename = lsb_release_attr("codename");
        if (!codename.empty) return codename;
        codename = distro_release_attr("codename");
        if (!codename.empty) return codename;
        return "";
    }

    struct VersionInfo {
        dstring id, version_, like, codename;
        Tuple!(dstring, "major", dstring, "minor", dstring, "build_number") version_parts;
    }

    /**
    Return certain machine-readable information about the OS
    distribution.
    For details, see :func:`distro.info`.
    */
    VersionInfo info(bool pretty=false, bool best=false) {
        return VersionInfo(
            /*id:*/ id(),
            /*version_:*/ version_(pretty, best),
            /*like:*/ like(),
            /*codename:*/ codename(),
            /*version_parts:*/ tuple(
                /*major:*/ major_version(best),
                /*minor:*/ minor_version(best),
                /*build_number:*/ build_number(best)
            ),
        );
    }

    /**
    Return a dictionary containing key-value pairs for the information
    items from the os-release file data source of the OS distribution.
    For details, see :func:`distro.os_release_info`.
    */
    dstring[dstring] os_release_info() {
        return _os_release_info;
    }

    /**
    Return a dictionary containing key-value pairs for the information
    items from the lsb_release command data source of the OS
    distribution.
    For details, see :func:`distro.lsb_release_info`.
    */
    dstring[dstring] lsb_release_info() {
        return _lsb_release_info;
    }

    /**
    Return a dictionary containing key-value pairs for the information
    items from the distro release file data source of the OS
    distribution.
    For details, see :func:`distro.distro_release_info`.
    */
    dstring[dstring] distro_release_info() {
        return _distro_release_info;
    }

    /**
    Return a dictionary containing key-value pairs for the information
    items from the uname command data source of the OS distribution.
    For details, see :func:`distro.uname_info`.
    */
    auto uname_info() {
        return _uname_info;
    }

    /**
    Return a single named information item from the os-release file data
    source of the OS distribution.
    For details, see :func:`distro.os_release_attr`.
    */
    dstring os_release_attr(dstring attribute) {
        return _os_release_info.get(attribute, "");
    }

    /**
    Return a single named information item from the lsb_release command
    output data source of the OS distribution.
    For details, see :func:`distro.lsb_release_attr`.
    */
    dstring lsb_release_attr(dstring attribute) {
        return _lsb_release_info.get(attribute, "");
    }

    /**
    Return a single named information item from the distro release file
    data source of the OS distribution.
    For details, see :func:`distro.distro_release_attr`.
    */
    dstring distro_release_attr(dstring attribute) {
        return _distro_release_info.get(attribute, "");
    }

    /**
    Return a single named information item from the uname command
    output data source of the OS distribution.
    For details, see :func:`distro.uname_release_attr`.
    */
    dstring uname_attr(dstring attribute) {
        return _uname_info.get(attribute, "");
    }

    /**
    Get the information items from the specified os-release file.
    Returns:
        A dictionary containing all information items.
    */
    @property dstring[dstring] _os_release_info_impl() {
        if (std.file.isFile(os_release_file)) {
            scope auto file = File(os_release_file);
            return _parse_os_release_content(release_file.byLine);
        }
        return {};
    }
    mixin Cached!("_os_release_info", "_os_release_info_impl");

    /**
    Parse the lines of an os-release file.
    Parameters:
    * lines: Iterable through the lines in the os-release file.
    Returns:
        A dictionary containing all information items.
    */
    static dstring[dstring] _parse_os_release_content(const dstring[] lines) {
        dstring[dstring] props;

        auto provider = new ShlexProviderStream!(dchar[]).ShlexProvider;
        ShlexProviderStream!(dchar[]).ShlexParams.WithDefaults params = {posix: true, whitespaceSplit: true};
        Shlex *lexer = provider.callWithDefaults(params);

        foreach(token; *lexer) {
            // At this point, all shell-like parsing has been done (i.e.
            // comments processed, quotes and backslash escape sequences
            // processed, multi-line values assembled, trailing newlines
            // stripped, etc.), so the tokens are now either:
            // * variable assignments: var=value
            // * commands or their arguments (not allowed in os-release)
            if('=' in token) {
                immutable eqPosition = token.find('=').front;
                immutable k = token[$..eqPosition];
                immutable v = token[eqPosition+1..$];
                props[k.lower()] = v;
                if(k == "VERSION") {
                    // this handles cases in which the codename is in
                    // the `(CODENAME)` (rhel, centos, fedora) format
                    // or in the `, CODENAME` format (Ubuntu).
                    static immutable ourRegex = regex(r"(\(\D+\))|,(\s+)?\D+");
                    auto codenameMatch = matchFirst(v, ourRegex);
                    if(!codenameMatch.empty) {
                        auto codename = codenameMatch[0];
                        codename = codename.strip("()");
                        codename = codename.strip(',');
                        codename = codename.strip();
                        // codename appears within paranthese.
                        props["codename"] = codename;
                    } else {
                        props["codename"] = "";
                    }
                }
            } else {
                // Ignore any tokens that are not variable assignments
            }
        }
        return props;
    }

    /**
    Get the information items from the lsb_release command output.
    Returns:
        A dictionary containing all information items.
    */
    @property dstring[dstring] _lsb_release_info_impl() {
        if(!include_lsb) return [];
        immutable response = execute(["lsb_release", "-a"]);
        if(response.status != 0) return [];
        immutable stdout = response.output;
        return _parse_lsb_release_content(stdout.splitLines); // TODO: in Python stdout.decode(sys.getfilesystemencoding())
    }
    mixin Cached!("_lsb_release_info", "_lsb_release_info_impl");

    /**
    Parse the output of the lsb_release command.
    Parameters:
    * lines: Iterable through the lines of the lsb_release output.
                Each line must be a unicode string or a UTF-8 encoded byte
                string.
    Returns:
        A dictionary containing all information items.
    */
    static dstring[dstring] _parse_lsb_release_content(const dstring[] lines) {
        dstring[dstring] props;
        foreach(immutable line; lines) {
            immutable line2 = line.strip('\n');
            if(!line2.find(':')) continue;
            immutable colonPosition = line2.find(':').front;
            immutable k = line2[$..colonPosition];
            immutable v = line2[colonPosition+1..$];
            props[k.replace(' ', '_').lower()] = v.strip();
        }
        return props;
    }

    @property dstring[dstring] _uname_info_impl() {
        immutable response = execute(["uname", "-rs"]);
        if(response.status != 0) return [];
        immutable stdout = response.output;
        return _parse_uname_content(stdout.splitLines); // TODO: stdout.decode(sys.getfilesystemencoding()) in Python
    }
    mixin Cached!("_uname_info", "_uname_info_impl");

    static dstring[dstring] _parse_uname_content(dstring[] lines) {
        dstring[dstring] props;
        static immutable r = regex(r"^([^\s]+)\s+([\d\.]+)");
        immutable match = matchFirst(lines[0].strip(), r); // FIXME: What if there is zero lines? (Also submit bug to Python?)
        if(!match.empty) {
            immutable name = match[1];
            immutable version_ = match[2];

            // This is to prevent the Linux kernel version from
            // appearing as the 'best' version on otherwise
            // identifiable distributions.
            if(name == "Linux") return [];
            props["id"] = name.lower();
            props["name"] = name;
            props["release"] = version_;
        }
        return props;
    }

    /**
    Get the information items from the specified distro release file.
    Returns:
        A dictionary containing all information items.
    */
    @property dstring[dstring] _distro_release_info_impl() {
        if(!distro_release_file.empty) {
            // If it was specified, we use it and parse what we can, even if
            // its file name or content does not match the expected pattern.
            auto distro_info = _parse_distro_release_file(distro_release_file);
            basename = os.path.basename(distro_release_file);
            // The file name pattern for user-specified distro release files
            // is somewhat more tolerant (compared to when searching for the
            // file), because we want to use what was specified as best as
            // possible.
            match = basename.matchFirst(_DISTRO_RELEASE_BASENAME_PATTERN);
            if(!match.empty) distro_info["id"] = match[1];
            return distro_info;
        } else {
            try {
                auto basenames = dirEntries(_UNIXCONFDIR, SpanMode.shallow);
                // We sort for repeatability in cases where there are multiple
                // distro specific files; e.g. CentOS, Oracle, Enterprise all
                // containing `redhat-release` on top of their own.
                basenames.sort();
            }
            catch(FileError) {
                // This may occur when /etc is not readable but we can't be
                // sure about the *-release files. Check common entries of
                // /etc for information. If they turn out to not be there the
                // error is handled in `_parse_distro_release_file()`.
                basenames = ["SuSE-release",
                             "arch-release",
                             "base-release",
                             "centos-release",
                             "fedora-release",
                             "gentoo-release",
                             "mageia-release",
                             "mandrake-release",
                             "mandriva-release",
                             "mandrivalinux-release",
                             "manjaro-release",
                             "oracle-release",
                             "redhat-release",
                             "sl-release",
                             "slackware-version"];
            }
            foreach(immutable basename; basenames) {
                if(basename in _DISTRO_RELEASE_IGNORE_BASENAMES) continue;
                match = basename.matchFirst(_DISTRO_RELEASE_BASENAME_PATTERN);
                if(!match.empty) {
                    immutable filepath = chainPath(_UNIXCONFDIR, basename);
                    auto distro_info = _parse_distro_release_file(filepath);
                    if("name" in distro_info) {
                        // The name is always present if the pattern matches
                        distro_release_file = filepath;
                        distro_info["id"] = match[1];
                        return distro_info;
                        }
                }
            }
            return [];
        }
    }
    mixin Cached!("_distro_release_info", "_distro_release_info_impl");

    /**
    Parse a distro release file.
    Parameters:
    * filepath: Path name of the distro release file.
    Returns:
        A dictionary containing all information items.
    */
    dstring[dstring] _parse_distro_release_file(string filepath) {
        try {
            scope fp = open(filepath);
            // Only parse the first line. For instance, on SLES there
            // are multiple lines. We don't want them...
            return _parse_distro_release_content(fp.readln());
        }
        // Ignore not being able to read a specific, seemingly version
        // related file.
        // See https://github.com/nir0s/distro/issues/162
        catch(ErrnoException) {
            return [];
        }
        catch(StdioException) {
            return [];
        }
    }

    /**
    Parse a line from a distro release file.
    Parameters:
    * line: Line from the distro release file. Must be a unicode string
            or a UTF-8 encoded byte string.
    Returns:
        A dictionary containing all information items.
    */
    static dstring[dstring] _parse_distro_release_content(const dstring line) {
        matches = line.strip.retro.dtext.matchFirst(_DISTRO_RELEASE_CONTENT_REVERSED_PATTERN);
        dstring[dstring] distro_info;
        if(!matches.empty) {
            // regexp ensures non-None
            distro_info["name"] = matches[3].retro;
            if(matches[2])
                distro_info["version_id"] = matches[2].retro;
            if(matches[1])
                distro_info["codename"] = matches[1].retro;
        } else if(!line.empty)
            distro_info["name"] = line.strip;
        return distro_info;
    }
}

/** TODO: Remove this as a global initilization? */
auto _distro = LinuxDistribution.create(); // TODO: Can we make it immutable?
