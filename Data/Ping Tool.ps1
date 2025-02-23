Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted

$currentDirectory = Get-Location
Write-Host $currentDirectory
$xamlPath = Join-Path $currentDirectory "\MainWindow.xaml"
$inputXAML=Get-Content -Path $xamlPath -Raw
$inputXAML=$inputXAML -replace 'mc:Ignorable="d"','' -replace "x:N","N" -replace '^<Win.*','<Window'
[XML]$XAML=$inputXAML

$reader = New-Object System.Xml.XmlNodeReader $XAML
try{
    $form1=[Windows.Markup.XamlReader]::Load($reader)
}catch{
    Write-Host $_.Exception
    throw
}

$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    try{
        Set-Variable -Name "var_$($_.Name)" -Value $form1.FindName($_.Name) -ErrorAction Stop
    }catch{
        throw
    }
}
Join-Path $currentDirectory "\icon-1024x 1024.ico"

$ping = New-Object System.Net.NetworkInformation.Ping
$pingOptions = New-Object System.Net.NetworkInformation.PingOptions
$pingOptions.Ttl = 64  # Optional: Adjust the TTL (Time To Live) if needed
$timeout = 200  # Set the timeout in milliseconds (200ms in this case)


$ColumnsIP=@(
    'Address'
    'Status'
)


$var_DataGrid_IP.FontSize= '18'
$IPDataTable=New-Object System.Data.DataTable
[void]$IPDataTable.Columns.AddRange($ColumnsIP)

$var_Label_IP.Visibility = "Hidden"

$var_Label_Status.Visibility= "Hidden"


function Add-PingResultToDataGrid($address, $status){

    $row = $IPDataTable.NewRow()
    $row['Address'] = $address
    $row['Status'] = $status
    $IPDataTable.Rows.Add($Row)
}


# Function to convert an IP address into its octet components
function Convert-IPToOctets($ipAddress) {
    return $ipAddress.Split('.') | ForEach-Object { [int]$_ }
}

# Function to convert octets back to an IP address string
function Convert-OctetsToIP($octets) {
    return "$($octets[0]).$($octets[1]).$($octets[2]).$($octets[3])"
}



# Function to loop through the range of IP addresses and ping each one
function Ping-IPRange($startIP, $endIP) {
    
    # Define the regex for validating IPv4 address format
    $ipRegex = '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

    if($startIP -notmatch $ipRegex -and $endIP -notmatch $ipRegex -or $endIP -eq $null){
        Write-Host "ERROR: Ip is not in the correct format"
        return
    }
    
    
    $startOctets = Convert-IPToOctets $startIP
    $endOctets = Convert-IPToOctets $endIP
    
    #if Only One IP Address is entered
    if($startOctets -ne 0 -and $endOctets -eq 0){
        $endOctets = $startOctets.Clone()
        $endOctets[3] = $startOctets[3]+1
    }

    
    # Exception handling to prevent incorrect similar ip addresses
    if($startOctets[0] -ne $endOctets[0] -or $startOctets[1] -ne $endOctets[1] -or $startOctets[2] -ne $endOctets[2]){
        Write-Host "ERROR: IP address need to match except the last digit"
        return 
    }

    # Exception to handle incorrect order or ips
    if($startOctets[3] -gt $endOctets[3]){
        Write-Host "Error: IP addresses are not in accending order"
        return
    }


    # Calculate the difference between the last octet
    $diff = $endOctets[3] - $startOctets[3]

    if($diff -gt 15){
        # Loop through the range (assuming the range is just the last octet for simplicity)
        for ($i = $startOctets[3]; $i -le $endOctets[3]; $i++) {
            $currentIP = "$($startOctets[0]).$($startOctets[1]).$($startOctets[2]).$i"
            $reply = $ping.Send($currentIP, $timeout)
       
            Add-PingResultToDataGrid $currentIP $reply.Status       
        }
    }
    else{
        # Loop through the range (assuming the range is just the last octet for simplicity)
        for ($i = $startOctets[3]; $i -lt $endOctets[3]; $i++) {
            $currentIP = "$($startOctets[0]).$($startOctets[1]).$($startOctets[2]).$i"
            $reply = $ping.Send($currentIP)
       
            Add-PingResultToDataGrid $currentIP $reply.Status       
    }
    }
    
    

    # Bind the DataGrid to the updated DataTable
    $var_DataGrid_IP.ItemsSource = $IPDataTable.DefaultView

}

# Event handler for when a row is clicked in the DataGrid
$var_DataGrid_IP.Add_MouseLeftButtonUp({
    $selectedItem = $var_DataGrid_IP.SelectedItem

    if ($selectedItem) {
        # Action to take when a row is clicked
        $ip = $selectedItem['Address']
        
        $reply = $ping.Send($ip)

        $var_Label_IP.Content = $ip

        $var_Label_Status.Content = $reply.Status

        $var_Label_IP.Visibility = "Visible"

        $var_Label_Status.Visibility= "Visible"
        
    }
})


$var_Button_Submit.Add_Click({

    $var_DataGrid_IP.Clear()
    $IPDataTable.Rows.Clear()
    $var_Label_IP.Visibility = "Hidden"
    $var_Label_Status.Visibility= "Hidden"

    $startIP = $var_IPStart.Text
    $endIP = $var_IPEnd.Text

    # Ping the range of IP addresses
    Ping-IPRange $startIP $endIP    

})

$var_Button_Help.Add_Click({

$help = "-SINGLE PING:  Type in one IP Address in start textbox to ping only one address`n-RANGE PING: Type in a range of IP's from start to end to ping multiple IP's in that range`n-RANGE PING(Functioality):  If numberof IPS to ping is greater the 15 then ping type changes to timeout mode to reduce loadtime of application`n -Any IP can be ping to completion by clicking it inside the datatable`n-Only a range of the final ip value can be iterated on"



[System.Windows.Forms.MessageBox]::Show($help)


})




# Show the form
$form1.ShowDialog()





