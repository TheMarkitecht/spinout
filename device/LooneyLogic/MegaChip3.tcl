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
