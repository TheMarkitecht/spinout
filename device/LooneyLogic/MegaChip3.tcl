# spinout
# Copyright 2020 Mark Hubbard, a.k.a. "TheMarkitecht"
# http://www.TheMarkitecht.com
#
# Project home:  http://github.com/TheMarkitecht/spinout
# spinout is a superb pinout creation, maintenance, and conversion tool
# for FPGA developers.
#
# This file is part of spinout.
#
# spinout is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# spinout is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with spinout.  If not, see <https://www.gnu.org/licenses/>.


# Spinout device library file describes several devices in the same techFamily.

class  Device_LooneyLogic_MC3-7800  Device  {
}

Device_LooneyLogic_MC3-7800  method  newEmpty  {}  {
    set brand LooneyLogic
    set partNum MC3-7800 ;# the complete number listed in the manufacturer's design tool software.
    set techFamily {MegaChip3}
    set density 78
    set package DIP40

    loop i 1 40 {
        set b $( $i / 8 + 1 )
        if { ! [$self bankExists $b]} {
            $self addBank $b
        }
        $self addPin $i $b
    }
}

######### keep adding other devices of the same techFamily here, by copying from those above.
