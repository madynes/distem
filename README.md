# This repository is no longer updated. The project is now hosted at https://gitlab.inria.fr/distem/distem




# Distem

Distem is a distributed systems emulator. When doing research on Cloud, P2P,
High Performance Computing or Grid systems, it can be used to transform an
homogenenous cluster (composed of identical nodes) into an experimental
platform where nodes have different performance, and are linked together
through a complex network topology, making it the ideal tool to benchmark
applications targetting such environments.

**Homepage: http://distem.gforge.inria.fr**

## Key features
* Uses modern Linux technology to steal resources from your applications
* Easy to install: on Grid'5000, you only need a few minutes to start to
  use Distem
* Easy to use: simple command-line interface for beginners, REST API for
  more experienced users
* Efficient and scalable: start a 10000-nodes virtual topology in less
  than 30 minutes


## Authors
* Lucas Nussbaum <lucas.nussbaum@loria.fr> (main contact point)
* Emmanuel Jeanvoine <emmanuel.jeanvoine@inria.fr>
* Luc Sarzyniec <luc.sarzyniec@inria.fr>
* Cristian Ruiz <cristian.ruiz@inria.fr>
* Alexandre Merlin <alexandre.merlin@inria.fr>

## License

Distem is Copyright © 2011 Lucas Nussbaum <lucas.nussbaum@loria.fr>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.



## Coding Style

* comments + commit messages in english
* documentation using rdoc
* indent with two spaces. With Vim, that does the trick:
```
autocmd BufNewFile,BufRead *.rb set ts=2 expandtab sw=2
```
