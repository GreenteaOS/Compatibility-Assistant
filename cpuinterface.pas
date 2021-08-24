{-----------------------------------
 Cpu Identifier interface declaration
-------------------------------------
 Interface that encapsulate detail of
 getting processor vendor  name, brand string
 supported features and etc
-------------------------------------
(c) 2017 Zamrony P. Juhara <zamronypj@yahoo.com>
http://github.com/zamronypj/cpuid
-------------------------------------}
unit CpuInterface;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type

   ICpuIdentifier = interface
       function cpuidSupported() : boolean;
       function vendorName() : string;
       function processorName() : string;
       function family() : byte;
       function model() : byte;
       function stepping() : byte;
       function hasFeature(const feature : string) : boolean;

       function maximumFrequency() : word;
       function baseFrequency() : word;
       function busReferenceFrequency() : word;
   end;

implementation

end.

