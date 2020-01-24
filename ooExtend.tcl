
# offer an easy way to declare a class method acting as an object factory.
# using this eliminates boilerplate in factory methods.
proc factory {className factoryMethodName argList body} {
    set argNames [lmap a $argList {lindex $a 0}] ;# strips any default values, leaving only names.
    uplevel 1 "
        proc  {$className $factoryMethodName}  {$argList}  {
            set self \[$className new\]
            \$self eval {$argNames} {$body}
            return \$self
        }
    "
}
