{-----------------------------------
 Cpu Identifier implementation
-------------------------------------
 Class that encapsulate detail of
 getting processor vendor  name, brand string
 supported features and etc
-------------------------------------
(c) 2017 Zamrony P. Juhara <zamronypj@yahoo.com>
http://github.com/zamronypj/cpuid
-------------------------------------}
unit Cpu;

{$mode objfpc}{$H+}
{$asmmode intel}

interface

uses
  Classes, SysUtils, CpuInterface;

type

   TCPUIDResult = record
       eax : cardinal;
       ebx : cardinal;
       ecx : cardinal;
       edx : cardinal;
   end;

   TCPUVendorId = array [0..2] of cardinal;
   TCPUVendorIdStr = array [0..11] of ansichar;

   TCPUBasicInfo = record
       operation : cardinal;
       case boolean of
           true : (VendorIdStr : TCPUVendorIdStr);
           false: (VendorId : TCPUVendorId);
   end;

   TCPUBrand = array[0..15] of ansichar;
   TCPUBrandString = record
       case boolean of
           true : (res : TCPUIDResult);
           false : (brand : TCPUBrand);
   end;

   TCPUExtInfo = record
       extOperation : cardinal;
       moreOperation : cardinal;
       extOperationAvail : boolean;
       brandStringAvail : boolean;
       brandString : string;
   end;

   { TCpu }

   TCpuIdentifier = class(TInterfacedObject, ICpuIdentifier)
   private
       function cpuidExec(const operation : cardinal) : TCPUIDResult;
       function getCPUBasicInfo() : TCPUBasicInfo;
       function getCPUExtInfo() : TCPUExtInfo;
   public
       function cpuidSupported() : boolean;
       function processorName() : string;
       function vendorName() : string;
       function hasFeature(const feature : string) : boolean;
       function family() : byte;
       function model() : byte;
       function stepping() : byte;

       function maximumFrequency() : word;
       function baseFrequency() : word;
       function busReferenceFrequency() : word;
   end;

implementation

{ TCpu }

const
    CPUID_BIT = $200000;

    CPUID_OPR_BASIC_INFO = 0;
    CPUID_OPR_VERSION_FEATURE_INFO = 1;
    CPUID_OPR_PROC_FREQUENCY_INFO = $16;

    CPUID_OPR_EXTENDED_INFO = $80000000;
    CPUID_OPR_EXTENDED_INFO_MORE = $80000001;

    CPUID_OPR_BRAND_INFO_AVAIL = $80000004;
    CPUID_OPR_BRAND_INFO_0 = $80000002;
    CPUID_OPR_BRAND_INFO_1 = $80000003;
    CPUID_OPR_BRAND_INFO_2 = $80000004;

{$IFDEF CPU32}
{------------start 32 bit architecture code ----------}

{**
 * Test availability of CPUID instruction
 *
 * @return boolean true if CPUID supported
 *}
function TCpuIdentifier.cpuidSupported() : boolean;
var supported:boolean;
begin
    asm
       push eax
       push ecx

       //copy EFLAGS -> EAX
       pushfd
       pop eax

       //store original RFLAGS
       //so we can restore it later
       mov ecx, eax

       //change bit 21
       xor eax, CPUID_BIT

       //copy EAX -> EFLAGS
       push eax
       popfd

       //copy EFLAGS back to EAX
       pushfd
       pop eax

       //CPUID_BIT is reserved bit and cannot be changed
       //for 386 processor or lower
       //if we can change, it means we run on newer processor

       and eax, CPUID_BIT
       shr eax, 21
       mov supported, al

       //restore original EFLAGS
       push ecx
       popfd

       pop ecx
       pop eax
    end;
    result := supported;
end;


{*
* Run CPUID instruction
* @param cardinal operation store code for operation to be performed
*}
function TCpuIdentifier.cpuidExec(const operation : cardinal) : TCPUIDResult;
var tmpEax, tmpEbx, tmpEcx, tmpEdx : cardinal;
begin
    asm
       push eax
       push ebx
       push ecx
       push edx

       mov eax, operation
       cpuid

       mov tmpEax, eax
       mov tmpEbx, ebx
       mov tmpEcx, ecx
       mov tmpEdx, edx

       pop edx
       pop ecx
       pop ebx
       pop eax
    end;
    result.eax := tmpEax;
    result.ebx := tmpEbx;
    result.ecx := tmpEcx;
    result.edx := tmpEdx;
end;
{------------end 32 bit architecture code ----------}
{$ENDIF}

{$IFDEF CPU64}
{------------start 64 bit architecture code ----------}

{**
 * Test availability of CPUID instruction
 *
 * @return boolean true if CPUID supported
 *}
function TCpuIdentifier.cpuidSupported() : boolean;
var supported:boolean;
begin
    asm
       push rax
       push rcx

       //copy RFLAGS -> RAX
       pushfq
       pop rax

       //store original RFLAGS
       //so we can restore it later
       mov rcx, rax

       //change bit 21
       xor rax, CPUID_BIT

       //copy RAX -> RFLAGS
       push rax
       popfq

       //copy RFLAGS back to EAX
       pushfq
       pop rax

       //CPUID_BIT is reserved bit and cannot be changed
       //for 386 processor or lower
       //if we can change, it means we run on newer processor

       and rax, CPUID_BIT
       shr rax, 21
       mov supported, al

       //restore original RFLAGS
       push rcx
       popfq

       pop rcx
       pop rax
    end;
    result := supported;
end;


{*
 * Run CPUID instruction
 * @param cardinal operation store code for operation to be performed
 *}
function TCpuIdentifier.cpuidExec(const operation : cardinal) : TCPUIDResult;
var tmpEax, tmpEbx, tmpEcx, tmpEdx : cardinal;
begin
    asm
      push rax
      push rbx
      push rcx
      push rdx

      mov eax, operation
      cpuid

      mov tmpEax, eax
      mov tmpEbx, ebx
      mov tmpEcx, ecx
      mov tmpEdx, edx

      pop rdx
      pop rcx
      pop rbx
      pop rax
    end;
    result.eax := tmpEax;
    result.ebx := tmpEbx;
    result.ecx := tmpEcx;
    result.edx := tmpEdx;
end;
{------------end 64 bit architecture code ----------}
{$ENDIF}

function TCpuIdentifier.getCPUBasicInfo() : TCPUBasicInfo;
var res:TCPUIDResult;
begin
    result := Default(TCPUBasicInfo);
    if not cpuidSupported() then
    begin
       exit;
    end;

    res := cpuidExec(CPUID_OPR_BASIC_INFO);
    result.operation   := res.eax;
    result.VendorId[0] := res.ebx;
    result.VendorId[1] := res.edx;
    result.VendorId[2] := res.ecx;
end;

function TCpuIdentifier.getCPUExtInfo() : TCPUExtInfo;
var res:TCPUIDResult;
    br:TCPUBrandString;
begin
    result := Default(TCPUExtInfo);
    if not cpuidSupported() then
    begin
        exit;
    end;

    res := cpuidExec(CPUID_OPR_EXTENDED_INFO_MORE);
    result.moreOperation := res.ecx;

    res := cpuidExec(CPUID_OPR_EXTENDED_INFO);
    result.extOperation := res.eax;
    result.extOperationAvail := (res.eax > CPUID_OPR_EXTENDED_INFO);
    result.brandStringAvail:=(res.eax >= CPUID_OPR_BRAND_INFO_AVAIL);
    result.brandString:='';
    if result.brandStringAvail then
    begin
        br.res := cpuidExec(CPUID_OPR_BRAND_INFO_0);
        result.brandString := result.brandString + br.brand;
        br.res := cpuidExec(CPUID_OPR_BRAND_INFO_1);
        result.brandString := result.brandString + br.brand;
        br.res := cpuidExec(CPUID_OPR_BRAND_INFO_2);
        result.brandString := result.brandString + br.brand;
    end;
end;

function TCpuIdentifier.processorName() : string;
var cpuExtInfo : TCPUExtInfo;
begin
    cpuExtInfo := getCPUExtInfo();
    result := cpuExtInfo.brandString;
end;

function TCpuIdentifier.vendorName() : string;
var basicInfo : TCPUBasicInfo;
begin
    basicInfo := getCPUBasicInfo();
    result := basicInfo.VendorIdStr;
end;

const
    CPUID_VERSION_EXTFAMILY_BIT   = $f00000;
    CPUID_VERSION_EXTMODEL_BIT    = $0f0000;
    CPUID_VERSION_PROCTYPE_BIT    = $003000;
    CPUID_VERSION_FAMILY_BIT      = $000f00;
    CPUID_VERSION_MODEL_BIT       = $0000f0;
    CPUID_VERSION_STEPPING_BIT    = $00000f;

function TCpuIdentifier.family() : byte;
var res:TCPUIDResult;
    familyValue, extFamilyValue : byte;
begin
    res := cpuidExec(CPUID_OPR_VERSION_FEATURE_INFO);
    familyValue := (res.eax and CPUID_VERSION_FAMILY_BIT) shr 8;
    result := familyValue;
    if (familyValue = $0f) then
    begin
        extFamilyValue := (res.eax and CPUID_VERSION_EXTFAMILY_BIT) shr 20;
        result := extFamilyValue + familyValue;
    end;
end;

function TCpuIdentifier.model(): byte;
var res:TCPUIDResult;
    modelValue, familyValue, extModelValue : byte;
begin
    res := cpuidExec(CPUID_OPR_VERSION_FEATURE_INFO);
    modelValue := (res.eax and CPUID_VERSION_MODEL_BIT) shr 4;
    familyValue := (res.eax and CPUID_VERSION_FAMILY_BIT) shr 8;
    result := modelValue;
    if ((familyValue = $06) or (familyValue = $0f)) then
    begin
        extModelValue := (res.eax and CPUID_VERSION_EXTMODEL_BIT) shr 16;
        result := (extModelValue shl 4) + modelValue;
    end;
end;

function TCpuIdentifier.stepping(): byte;
var res:TCPUIDResult;
begin
    res := cpuidExec(CPUID_OPR_VERSION_FEATURE_INFO);
    result := res.eax and CPUID_VERSION_STEPPING_BIT;
end;

function TCpuIdentifier.maximumFrequency() : word;
var res:TCPUIDResult;
begin
    res := cpuidExec(CPUID_OPR_PROC_FREQUENCY_INFO);
    result := res.ebx and $ff;
end;

function TCpuIdentifier.baseFrequency() : word;
var res:TCPUIDResult;
begin
    res := cpuidExec(CPUID_OPR_PROC_FREQUENCY_INFO);
    result := res.eax and $ff;
end;

function TCpuIdentifier.busReferenceFrequency() : word;
var res:TCPUIDResult;
begin
    res := cpuidExec(CPUID_OPR_PROC_FREQUENCY_INFO);
    result := res.ecx and $ff;
end;

function TCpuIdentifier.hasFeature(const feature: string): boolean;
var res:TCPUIDResult;
begin
    result := false;
    res := cpuidExec(CPUID_OPR_VERSION_FEATURE_INFO);
    case feature of
       'SSE3'         : result := ((res.ecx and $1) = $1);
       'PCLMULQDQ'    : result := ((res.ecx and $2) = $2);
       'DTES64'       : result := ((res.ecx and $4) = $4);
       'MONITOR'      : result := ((res.ecx and $8) = $8);
       'DS-CPL'       : result := ((res.ecx and $10) = $10);
       'VMX'          : result := ((res.ecx and $20) = $20);
       'SMX'          : result := ((res.ecx and $40) = $40);
       'EIST'         : result := ((res.ecx and $80) = $80);
       'TM2'          : result := ((res.ecx and $100) = $100);
       'SSSE3'        : result := ((res.ecx and $200) = $200);
       'CNXT-ID'      : result := ((res.ecx and $400) = $400);
       'SDBG'         : result := ((res.ecx and $800) = $800);
       'FMA'          : result := ((res.ecx and $1000) = $1000);
       'CMPXCHG16B'   : result := ((res.ecx and $2000) = $2000);
       'xTPR'         : result := ((res.ecx and $4000) = $4000);
       'PDCM'         : result := ((res.ecx and $8000) = $8000);
       //'reserved'   : result := ((res.ecx and $10000) = $10000);
       'PCID'         : result := ((res.ecx and $20000) = $20000);
       'DCA'          : result := ((res.ecx and $40000) = $40000);
       'SSE4_1'       : result := ((res.ecx and $80000) = $80000);
       'SSE4_2'       : result := ((res.ecx and $100000) = $100000);
       'x2APIC'       : result := ((res.ecx and $200000) = $200000);
       'MOVBE'        : result := ((res.ecx and $400000) = $400000);
       'POPCNT'       : result := ((res.ecx and $800000) = $800000);
       'TSC-DEADLINE' : result := ((res.ecx and $1000000) = $1000000);
       'AES'          : result := ((res.ecx and $2000000) = $2000000);
       'XSAVE'        : result := ((res.ecx and $4000000) = $4000000);
       'OSXSAVE'      : result := ((res.ecx and $8000000) = $8000000);
       'AVX'          : result := ((res.ecx and $10000000) = $10000000);
       'F16C'         : result := ((res.ecx and $20000000) = $20000000);
       'RDRAND'       : result := ((res.ecx and $40000000) = $40000000);
       //'notused'    : result := ((res.ecx and $80000000) = $80000000);

       'FPU'          : result := ((res.edx and $1) = $1);
       'VME'          : result := ((res.edx and $2) = $2);
       'DE'           : result := ((res.edx and $4) = $4);
       'PSE'          : result := ((res.edx and $8) = $8);
       'TSC'          : result := ((res.edx and $10) = $10);
       'MSR'          : result := ((res.edx and $20) = $20);
       'PAE'          : result := ((res.edx and $40) = $40);
       'MCE'          : result := ((res.edx and $80) = $80);
       'CX8'          : result := ((res.edx and $100) = $100);
       'APIC'         : result := ((res.edx and $200) = $200);
       //'reserved'   : result := ((res.edx and $400) = $400);
       'SEP'          : result := ((res.edx and $800) = $800);
       'MTRR'         : result := ((res.edx and $1000) = $1000);
       'PGE'          : result := ((res.edx and $2000) = $2000);
       'MCA'          : result := ((res.edx and $4000) = $4000);
       'CMOV'         : result := ((res.edx and $8000) = $8000);
       'PAT'          : result := ((res.edx and $10000) = $10000);
       'PSE-36'       : result := ((res.edx and $20000) = $20000);
       'PSN'          : result := ((res.edx and $40000) = $40000);
       'CLFSH'        : result := ((res.edx and $80000) = $80000);
       //'reserved'   : result := ((res.edx and $100000) = $100000);
       'DS'           : result := ((res.edx and $200000) = $200000);
       'ACPI'         : result := ((res.edx and $400000) = $400000);
       'MMX'          : result := ((res.edx and $800000) = $800000);
       'FXSR'         : result := ((res.edx and $1000000) = $1000000);
       'SSE'          : result := ((res.edx and $2000000) = $2000000);
       'SSE2'         : result := ((res.edx and $4000000) = $4000000);
       'SS'           : result := ((res.edx and $8000000) = $8000000);
       'HTT'          : result := ((res.edx and $10000000) = $10000000);
       'TM'           : result := ((res.edx and $20000000) = $20000000);
       //'reserved'   : result := ((res.edx and $40000000) = $40000000);
       'PBE'          : result := ((res.edx and $80000000) = $80000000);
    end;

    res := cpuidExec(CPUID_OPR_EXTENDED_INFO_MORE);
    case feature of
       'SAHF'          : result := ((res.ecx and $1) = $1);
       'PREFETCHW'          : result := ((res.ecx and $100) = $100);
    end;
end;

end.

