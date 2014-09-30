unit TestsParallelThread;
{

  Delphi DUnit Test Case
  ----------------------
  This unit contains a skeleton test case class generated by the Test Case Wizard.
  Modify the generated code to correctly setup and call the methods from the unit 
  being tested.

}

interface

uses
  TestFramework
  , sParallelThread
  , Classes
  , ExtCtrls
  , SysUtils
  , Contnrs
  , SyncObjs
  , Windows
  ;

type
  // Test methods for class TsParallelThreadManager
  
  TestTsParallelThreadManager = class(TTestCase)
  private
    FsParallelThreadManager: TsParallelThreadManager;
    FTestPushIsOk: Boolean;
  public
    procedure Delay(AInterval: Integer);
  procedure OnParallelWork(AData: TObject);
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestPush;
  end;

implementation

uses
  Forms
  ;
procedure TestTsParallelThreadManager.Delay(AInterval: Integer);
var
  start: Cardinal;
begin
  start := GetTickCount;
  while GetTickCount - start < AInterval do
  begin
    Application.ProcessMessages;
    sleep(1);


  end;

end;

procedure TestTsParallelThreadManager.OnParallelWork(AData: TObject);
begin
  FTestPushIsOk := True;
end;

procedure TestTsParallelThreadManager.SetUp;
begin
  FsParallelThreadManager := TsParallelThreadManager.Create;
  FsParallelThreadManager.OnParallelWork := OnParallelWork;
end;

procedure TestTsParallelThreadManager.TearDown;
begin
  FsParallelThreadManager.Free;
  FsParallelThreadManager := nil;
end;

procedure TestTsParallelThreadManager.TestPush;
var
  AData: TObject;
begin
  FTestPushIsOk := False;
  AData := TObject.Create;
  FsParallelThreadManager.Push(AData);
  Delay(100);
  Check(FTestPushIsOk);
  
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestTsParallelThreadManager.Suite);
end.
