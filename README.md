# spinout

Project home:  [http://github.com/TheMarkitecht/spinout](http://github.com/TheMarkitecht/spinout)

Legal stuff:  see below.

---

## Introduction:

**spinout** is a superb pinout creation, maintenance, and conversion tool for FPGA developers.
**spinout** is vendor-agnostic; not limited to one or two FPGA vendors.
**spinout** runs on [Jim Tcl](http://jim.tcl.tk/), the small-footprint Tcl interpreter.

## Features of This Version:

* This initial version has proven usable in applications.
* Loads and saves CSV files suitable for collaborating in [Notion](http://notion.so), or spreadsheets, or other apps.
* Integrates with Intel Quartus command-line tools to interact with your FPGA design in real time.
* Outputs
* Usable in scripts, or interactively on the command line using ordinary jimsh.

## Requirements:

* Jim 0.79 or later
* [slim OOP package](http://github.com/TheMarkitecht/slim)

## Building:

There is no build process.  Simply **package require spinout**; see the top of **spinout.tcl** for details.

## Future Direction:

* Bug fixes
* Support more data fields, such as drive strength.
* More device files.
* Automatically unzip the markdown+CSV zip file exported by Notion.
* Xilinx Vivado support.  The existing vendor-independent approach should make this easy.

## Legal stuff:
```
  spinout
  Copyright 2020 Mark Hubbard, a.k.a. "TheMarkitecht"
  http://www.TheMarkitecht.com

  Project home:  http://github.com/TheMarkitecht/spinout
  spinout is a superb pinout creation, maintenance, and conversion tool
  for FPGA developers.

  This file is part of spinout.

  spinout is free software: you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  spinout is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with spinout.  If not, see <https://www.gnu.org/licenses/>.
```

See [COPYING.LESSER](COPYING.LESSER) and [COPYING](COPYING).

## Contact:

Send donations, praise, curses, and the occasional question to: `Mark-ate-TheMarkitecht-dote-com`

## Final Word:

I hope you enjoy this software.  If you enhance it, port it to another environment,
or just use it in your project etc., by all means let me know.

>  \- TheMarkitecht

---
