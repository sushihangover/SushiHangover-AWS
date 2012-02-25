## Copyright 2012 Robert Nees
## Licensed under the Apache License, Version 2.0 (the "License");
## http://sushihangover.blogspot.com
##
$likeMe = "%" + $args[0] + "%"
$app = Get-WmiObject -query "SELECT * FROM Win32_Product WHERE Name LIKE '$likeMe'"
if ($app.count -gt 1) {
    $app
    exit
}
if ($app -ne $null) {
    $app.Name
    $message = "Do you want to uninstall this program?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Uninstall the program."
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Exit script; do not uninstall the program."
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($no, $yes)
    $result = $host.ui.PromptForChoice($title, $message, $options, 0)
    switch ($result)
    {
        1 {
            $app.Uninstall()
        }
        0 {
            exit
        }
    }
}

