
package require oo

# offer an easy way to declare a class method acting as an object factory.
# using this eliminates boilerplate in factory methods.
proc factory {className factoryMethodName argList body} {
    set argNames [lmap a $argList {lindex $a 0}] ;# strips any default values, leaving only names.
    set callArgs [lmap a $argNames {expr {"\$$a"}}] ;# prepends a $ on each name.
puts "$className method _$factoryMethodName  $argNames  $body"
    $className method _$factoryMethodName  $argNames  $body
    proc  "$className $factoryMethodName"  $argList  "
        set self \[$className new\]
        \$self _$factoryMethodName $callArgs
        return \$self
    "
}
