module shlex_main;

import std.stdio;
import distro;

void main(string[] args)
{
    auto distro = LinuxDistribution.create();
    writeln(distro);
}
