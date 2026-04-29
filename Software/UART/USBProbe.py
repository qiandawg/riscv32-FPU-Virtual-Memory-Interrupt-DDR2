import win32com.client

objSWbemServices = win32com.client.Dispatch("WbemScripting.SWbemLocator").ConnectServer(".","root\cimv2")

for item in objSWbemServices.ExecQuery("SELECT * FROM Win32_PnPEntity"):
    print('-'*60)
    for name in ('Availability', 'Caption', 'ClassGuid', 'ConfigManagerUserConfig',
                 'CreationClassName', 'Description','DeviceID', 'ErrorCleared', 'ErrorDescription',
                 'InstallDate', 'LastErrorCode', 'Manufacturer', 'Name', 'PNPDeviceID', 'PowerManagementCapabilities ',
                 'PowerManagementSupported', 'Service', 'Status', 'StatusInfo', 'SystemCreationClassName', 'SystemName'):
        a = getattr(item, name, None)
        if a is not None:
            print('%s: %s' % (name, a))