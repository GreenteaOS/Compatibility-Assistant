unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Windows, CpuInterface, Clipbrd;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Image1: TImage;
    Label1: TLabel;
    LabelNX: TLabel;
    LabelDISK: TLabel;
    LabelCX16: TLabel;
    LabelPDPE1GB: TLabel;
    LabelSSE4_2: TLabel;
    LabelSAHF: TLabel;
    LabelPF: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    LabelAVX: TLabel;
    LabelSSE3: TLabel;
    LabelPOPCNT: TLabel;
    LabelSSE4_1: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Image1Click(Sender: TObject);
    procedure Label6Click(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

uses cpu;

{$R *.lfm}

{ TForm1 }

function IsWindows64: boolean;
  {
  Detect if we are running on 64 bit Windows or 32 bit Windows,
  independently of bitness of this program.
  Original source:
  http://www.delphipraxis.net/118485-ermitteln-ob-32-bit-oder-64-bit-betriebssystem.html
  modified for FreePascal in German Lazarus forum:
  http://www.lazarusforum.de/viewtopic.php?f=55&t=5287
  }
{$ifdef WIN32} //Modified KpjComp for 64bit compile mode
  type
    TIsWow64Process = function( // Type of IsWow64Process API fn
        Handle: THandle; var Res: Windows.BOOL): Windows.BOOL; stdcall;
  var
    IsWow64Result: Windows.BOOL; // Result from IsWow64Process
    IsWow64Process: TIsWow64Process; // IsWow64Process fn reference
  begin
    // Try to load required function from kernel32
    IsWow64Process := TIsWow64Process(Windows.GetProcAddress(
      Windows.GetModuleHandle('kernel32'), 'IsWow64Process'));
    if Assigned(IsWow64Process) then
    begin
      // Function is implemented: call it
      if not IsWow64Process(Windows.GetCurrentProcess, IsWow64Result) then
        raise SysUtils.Exception.Create('IsWindows64: bad process handle');
      // Return result of function
      Result := IsWow64Result;
    end
    else
      // Function not implemented: can't be running on Wow64
      Result := False;
{$else} //if were running 64bit code, OS must be 64bit :)
  begin
   Result := True;
{$endif}
end;

type
  MEMORYSTATUSEX = record
     dwLength : DWORD;
     dwMemoryLoad : DWORD;
     ullTotalPhys : uint64;
     ullAvailPhys : uint64;
     ullTotalPageFile : uint64;
     ullAvailPageFile : uint64;
     ullTotalVirtual : uint64;
     ullAvailVirtual : uint64;
     ullAvailExtendedVirtual : uint64;
  end;

function GlobalMemoryStatusEx(var Buffer: MEMORYSTATUSEX): BOOL; stdcall; external 'kernel32' name 'GlobalMemoryStatusEx';

function GetSystemMem: uint64;
var MS_Ex: MemoryStatusEx;
begin
 result := 0;
 FillChar(MS_Ex, SizeOf(MemoryStatusEx), 0);
 MS_Ex.dwLength := SizeOf(MemoryStatusEx);
 if GlobalMemoryStatusEx(MS_Ex) then
  result := (MS_Ex.ullTotalPhys + 1024*1024*512) div (1024*1024*1024); // FormatFloat('###.##', MS_Ex.ullTotalPhys / (1024*1024*1024)) + ' GB';
 // TODO round up
end;

function supportedFeature(const cpuIntf: ICpuIdentifier; const feature: string): string;
begin
   result := '';
   if (cpuIntf.hasFeature(feature)) then
   begin
      result := feature;
   end;
end;

function reportAllSupportedFeatures(const cpuIntf: ICpuIdentifier): string;
const
   startFeatureIndex = 0;
   endFeatureIndex = 58;
var features : array [startFeatureIndex..endFeatureIndex] of string = (
      'SSE3', 'PCLMULQDQ', 'DTES64', 'MONITOR', 'DS-CPL', 'VMX',
      'SMX', 'EIST', 'TM2', 'SSSE3', 'CNXT-ID', 'SDBG', 'FMA',
      'CMPXCHG16B', 'xTPR', 'PDCM', 'PCID', 'DCA', 'SSE4_1',
      'SSE4_2', 'x2APIC', 'MOVBE', 'POPCNT', 'TSC-DEADLINE',
      'AES', 'XSAVE', 'OSXSAVE', 'AVX', 'F16C',
      'RDRAND', 'FPU', 'VME', 'DE', 'PSE', 'TSC', 'MSR',
      'PAE', 'MCE', 'CX8', 'APIC', 'SEP', 'MTRR', 'PGE',
      'MCA', 'CMOV', 'PAT', 'PSE-36', 'PSN', 'CLFSH', 'DS',
      'ACPI', 'MMX', 'FXSR', 'SSE', 'SSE2', 'SS', 'HTT', 'TM', 'PBE'
    );

    i:integer;
    tmp:string;
begin
   result:='';
   for i := startFeatureIndex to endFeatureIndex do
   begin
      tmp:= supportedFeature(cpuIntf, features[i]);
      if (length(tmp) > 0) then
      begin
         result:= result + tmp + ' ';
      end;
   end;
end;

type
  TDriveLayoutInformationMbr = record
    Signature: DWORD;
  end;

  TDriveLayoutInformationGpt = record
    DiskId: TGuid;
    StartingUsableOffset: Int64;
    UsableLength: Int64;
    MaxPartitionCount: DWORD;
  end;

  TPartitionInformationMbr = record
    PartitionType: Byte;
    BootIndicator: Boolean;
    RecognizedPartition: Boolean;
    HiddenSectors: DWORD;
  end;

  TPartitionInformationGpt = record
    PartitionType: TGuid;
    PartitionId: TGuid;
    Attributes: Int64;
    Name: array [0..35] of WideChar;
  end;

  TPartitionInformationEx = record
    PartitionStyle: Integer;
    StartingOffset: Int64;
    PartitionLength: Int64;
    PartitionNumber: DWORD;
    RewritePartition: Boolean;
    case Integer of
      0: (Mbr: TPartitionInformationMbr);
      1: (Gpt: TPartitionInformationGpt);
  end;

  TDriveLayoutInformationEx = record
    PartitionStyle: DWORD;
    PartitionCount: DWORD;
    DriveLayoutInformation: record
      case Integer of
      0: (Mbr: TDriveLayoutInformationMbr);
      1: (Gpt: TDriveLayoutInformationGpt);
    end;
    PartitionEntry: array [0..15] of TPartitionInformationGpt;
    //hard-coded maximum of 16 partitions
  end;

const
  PARTITION_STYLE_MBR = 0;
  PARTITION_STYLE_GPT = 1;
  PARTITION_STYLE_RAW = 2;

const
  IOCTL_DISK_GET_DRIVE_LAYOUT_EX = $00070050;

function layout: string;
const
  // Max number of drives assuming primary/secondary, master/slave topology
  MAX_IDE_DRIVES = 16;
var
  i: Integer;
  Drive: string;
  hDevice: THandle;
  DriveLayoutInfo: TDriveLayoutInformationEx;
  BytesReturned: DWORD;
begin
  result := '{';
  for i := 0 to MAX_IDE_DRIVES - 1 do
  begin
    Drive := '\\.\PHYSICALDRIVE' + IntToStr(i);
    hDevice := CreateFile(PChar(Drive), 0, FILE_SHARE_READ or FILE_SHARE_WRITE,
      nil, OPEN_EXISTING, 0, 0);
    if hDevice <> INVALID_HANDLE_VALUE then
    begin
      if DeviceIoControl(hDevice, IOCTL_DISK_GET_DRIVE_LAYOUT_EX, nil, 0,
        @DriveLayoutInfo, SizeOf(DriveLayoutInfo), BytesReturned, nil) then
      begin
        case DriveLayoutInfo.PartitionStyle of
        PARTITION_STYLE_MBR:
          result := result + '(MBR)';
          //Writeln(Drive + ', MBR, ' +
          //  IntToHex(DriveLayoutInfo.DriveLayoutInformation.Mbr.Signature, 8));
        PARTITION_STYLE_GPT:
          result := result + '(GPT)';
          //Writeln(Drive + ', GPT, ' +
          //  GUIDToString(DriveLayoutInfo.DriveLayoutInformation.Gpt.DiskId));
        PARTITION_STYLE_RAW:
          result := result + '(GPT)';
          //Writeln(Drive + ', RAW');
        end;
      end;
      CloseHandle(hDevice);
    end;
  end;

  result := result + '}';
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  cpus: LongWord;
  w64: boolean;
  mem: uint64;
  processor : ICpuIdentifier;

begin
  cpus := GetCPUCount();
  w64 := IsWindows64;
  mem := GetSystemMem;
  processor := TCpuIdentifier.Create();

  Label1.Caption :='CPU threads count is ' + IntToStr(cpus);
  Label1.Color := clRed;
  if cpus > 1 then
     Label1.Color := clMoneyGreen;

  if w64 then begin
     Label2.Color := clMoneyGreen;
     Label2.Caption := 'CPU is 64-bit';
  end else begin
     Label2.Color := clRed;
     Label2.Caption := 'CPU is 32-bit';
  end;

  Button2.Enabled := true;

  if mem > 1 then begin
     Label4.Color := clMoneyGreen;
  end else begin
     Label4.Color := clRed;
  end;

  Label4.Caption := 'RAM is ' + FormatFloat('###.##', mem) + ' GB';

  Label7.Caption := Trim(processor.processorName());

  if processor.hasFeature('x2APIC') then
  Label7.Caption := Label7.Caption + ' (x2APIC)'
  else Label7.Caption := Label7.Caption + ' (Legacy APIC)';

  if processor.hasFeature('x2APIC') or processor.hasFeature('APIC') then
  Label7.Color := clMoneyGreen
  else Label7.Color := clRed;

  Label7.Hint := reportAllSupportedFeatures(processor);

  // '-msse3 -mpopcnt -mcx16 -msahf -mprfchw ',

  if processor.hasFeature('POPCNT') then
  LabelPOPCNT.Color := clMoneyGreen
  else LabelPOPCNT.Color := clRed;
  LabelPOPCNT.Caption := 'POPCNT';

  if processor.hasFeature('SSE3') then
  LabelSSE3.Color := clMoneyGreen
  else LabelSSE3.Color := clRed;
  LabelSSE3.Caption := 'SSE3';

  if processor.hasFeature('CMPXCHG16B') then
  LabelCX16.Color := clMoneyGreen
  else LabelCX16.Color := clRed;
  LabelCX16.Caption := 'CMPXCHG16B';

  if processor.hasFeature('SAHF') then
  LabelSAHF.Color := clMoneyGreen
  else LabelSAHF.Color := clRed;
  LabelSAHF.Caption := 'SAHF';

  if processor.hasFeature('PREFETCHW') then
  LabelPF.Color := clMoneyGreen
  else LabelPF.Color := clCream;
  LabelPF.Caption := 'PREFETCHW';

  // ---

  if processor.hasFeature('SSE4_1') then
  LabelSSE4_1.Color := clMoneyGreen
  else LabelSSE4_1.Color := clRed;
  LabelSSE4_1.Caption := 'SSE4_1';

  if processor.hasFeature('SSE4_2') then
  LabelSSE4_2.Color := clMoneyGreen
  else LabelSSE4_2.Color := clRed;
  LabelSSE4_2.Caption := 'SSE4_2';

  if processor.hasFeature('NX') then
  LabelNX.Color := clMoneyGreen
  else LabelNX.Color := clCream;
  LabelNX.Caption := 'NX';

  if processor.hasFeature('AVX') then
  LabelAVX.Color := clMoneyGreen
  else LabelAVX.Color := clCream;
  LabelAVX.Caption := 'AVX';

  if processor.hasFeature('PDPE1GB') then
  LabelPDPE1GB.Color := clMoneyGreen
  else LabelPDPE1GB.Color := clCream;
  LabelPDPE1GB.Caption := 'PDPE1GB';

  // TODO UEFI/GPT

  LabelDISK.Hint := layout;
  if pos('(GPT)', LabelDISK.Hint) > 1 then begin
     LabelDISK.Color := clMoneyGreen;
     LabelDISK.Caption := 'GPT partition scheme';
  end else begin
     LabelDISK.Color := clRed;
     LabelDISK.Caption := 'MBR partition scheme';
  end;


end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  Clipboard.AsText :=
  Label7.Caption + ''#13#10'' +
  Label1.Caption + ''#13#10'' +
  Label2.Caption + ''#13#10'' +
  Label4.Caption + ''#13#10'' +
  LabelDISK.Caption + ''#13#10'' +

  LabelPOPCNT.Caption + ''#13#10'' +
  LabelSSE3.Caption + ''#13#10'' +
  LabelCX16.Caption + ''#13#10'' +
  LabelSAHF.Caption + ''#13#10'' +
  LabelPF.Caption + ''#13#10'' +

  Label7.Hint + ''#13#10''
  ;
end;

procedure TForm1.Image1Click(Sender: TObject);
begin

end;

procedure TForm1.Label6Click(Sender: TObject);
begin

end;

end.

