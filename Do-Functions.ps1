## Copyright 2012 Robert Nees
## Licensed under the Apache License, Version 2.0 (the "License");
## http://sushihangover.blogspot.com
##
function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
}