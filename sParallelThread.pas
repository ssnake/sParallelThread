{
  Author: snake
  Date: 2014-09-30
  site: snakelab.cc

  Changelog:

              v0.5 - first release
  2014-10-01  v0.6 - use thread timer instead of TTimer
  2014-10-03  v0.7 - fixed mem leaks, data is freed within thread
  2014-10-06  v0.71 - fixed frozen thread issue
  2014-10-07  v0.8  - got rid of timer in TsParallelManager
                      use IParallelData instead of TObject

}
unit sParallelThread;

interface

uses
  Classes
  , Contnrs
  , SyncObjs
  , ExtCtrls
  , SysUtils
  ;

type
  IParallelData = interface(IInterface)
  ['{0B6BC72A-1090-4B0E-85B3-C7FF40139888}']
    function GetAnsiStr1: Ansistring; stdcall;
    function GetAnsiStr2: Ansistring; stdcall;
    function GetAnsiStr3: Ansistring; stdcall;
    function GetInt1: Integer; stdcall;
    function GetInt2: Integer; stdcall;
    function GetInt3: Integer; stdcall;
    function GetObjectList: TList; stdcall;
    function GetStrList: TStrings; stdcall;
    procedure SetAnsiStr1(const Value: Ansistring); stdcall;
    procedure SetAnsiStr2(const Value: Ansistring); stdcall;
    procedure SetAnsiStr3(const Value: Ansistring); stdcall;
    procedure SetInt1(const Value: Integer); stdcall;
    procedure SetInt2(const Value: Integer); stdcall;
    procedure SetInt3(const Value: Integer); stdcall;
    property AnsiStr1: Ansistring read GetAnsiStr1 write SetAnsiStr1;
    property AnsiStr2: Ansistring read GetAnsiStr2 write SetAnsiStr2;
    property AnsiStr3: Ansistring read GetAnsiStr3 write SetAnsiStr3;
    property Int1: Integer read GetInt1 write SetInt1;
    property Int2: Integer read GetInt2 write SetInt2;
    property Int3: Integer read GetInt3 write SetInt3;
    property ObjectList: TList read GetObjectList;
    property StrList: TStrings read GetStrList;
  end;

  TsParallelData = class(TInterfacedObject, IParallelData)
  private
    FAnsiStr1: Ansistring;
    FAnsiStr2: Ansistring;
    FAnsiStr3: Ansistring;
    FInt1: Integer;
    FInt2: Integer;
    FInt3: Integer;
    FObjectList: TList;
    FStrList: TStrings;
  public
    constructor Create;
    destructor Destroy; override;
  published
    function GetAnsiStr1: Ansistring; stdcall;
    function GetAnsiStr2: Ansistring; stdcall;
    function GetAnsiStr3: Ansistring; stdcall;
    function GetInt1: Integer; stdcall;
    function GetInt2: Integer; stdcall;
    function GetInt3: Integer; stdcall;
    function GetObjectList: TList; stdcall;
    function GetStrList: TStrings; stdcall;
    procedure SetAnsiStr1(const Value: Ansistring); stdcall;
    procedure SetAnsiStr2(const Value: Ansistring); stdcall;
    procedure SetAnsiStr3(const Value: Ansistring); stdcall;
    procedure SetInt1(const Value: Integer); stdcall;
    procedure SetInt2(const Value: Integer); stdcall;
    procedure SetInt3(const Value: Integer); stdcall;

  end;
  
  TsParallelEvent = procedure(AData: IParallelData) of object;
  TsErrorEvent = procedure(E: Exception) of object;
  TsParallelThreadManager = class;
  TsParallelThread = class(TThread)
  private
    FCS: TCriticalSection;
    FDataList: TInterfaceList;
    FException: Exception;
    FManager: TsParallelThreadManager;
    procedure DoError;
  protected
    procedure Execute; override;
  public
    constructor Create(AManger: TsParallelThreadManager);
    destructor Destroy; override;
    function WorkAmount: Integer;
    procedure Start(AData: IParallelData);
  end;
  TsThreadTimer = class(TThread)
  private
    FEvent: TEvent;
    FOnTimer: TNotifyEvent;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    property OnTimer: TNotifyEvent read FOnTimer write FOnTimer;
  end;
  TsParallelThreadManager = class(TObject)
  private
    FCS: TCriticalSection;
    FDestroying: Boolean;
    FOnError: TsErrorEvent;
    FOnParallelWork: TsParallelEvent;
    FThreadList: TList;
    function GetFreeThread: TsParallelThread;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Push(AData: IParallelData);
    property OnError: TsErrorEvent read FOnError write FOnError;
    property OnParallelWork: TsParallelEvent read FOnParallelWork write
        FOnParallelWork;
  end;







implementation

constructor TsParallelThreadManager.Create;
begin
  inherited;
  FDestroying := False;
  FCS := TCriticalSection.Create;
 
  FThreadList := TObjectList.Create;
  FThreadList.Add(TsParallelThread.Create(self));


end;

destructor TsParallelThreadManager.Destroy;
begin
  inherited;
  FDestroying := True;
  FCS.Enter;


  FThreadList.Free;

  FCS.Free;
end;

function TsParallelThreadManager.GetFreeThread: TsParallelThread;
var
  i, c, w: Integer;
  thread: TsParallelThread;
begin
  Result := nil;
  c :=  MaxInt;
  for I := 0 to FThreadList.Count - 1 do
  begin
    thread := TsParallelThread(FThreadList[I]);
    w := thread.WorkAmount;
    if c > w then
    begin
      Result := thread;
      c := w;
    end;

  end;
end;

procedure TsParallelThreadManager.Push(AData: IParallelData);
var
  thread: TsParallelThread;
begin
  if FDestroying then
    exit;

  thread := GetFreeThread;
  assert(Assigned(thread));
  thread.Start(AData); 

end;

constructor TsParallelThread.Create(AManger: TsParallelThreadManager);
begin
  inherited Create(True);
  FManager := AManger;
  FDataList := TInterfaceList.Create;
  FCS := TCriticalSection.Create;
end;

destructor TsParallelThread.Destroy;
begin
  inherited;
  FCS.Enter;
  try
    if Assigned(FDataList) then
      FreeAndNil(FDataList);
  finally
    FCS.Leave;
  end;
  FCS.Free;
end;

procedure TsParallelThread.DoError;
begin
  FManager.OnError(FException);
end;

procedure TsParallelThread.Execute;
var
  data: IParallelData;
begin
  while not Terminated do
  begin

    while WorkAmount > 0 do
    begin
      try
        try
          FCS.Enter;
          try
            data := FDataList[0] as IParallelData;
            FDatalist.Delete(0);
          finally
            FCS.Leave;
          end;

          if Assigned(FManager.OnParallelWork) then
            FManager.OnParallelWork(data);
        except
          on E: exception  do
          begin
            FException := E;
            if Assigned(FManager.OnError) then
              Synchronize(DoError);
          end;


        end;

      finally
      end;

    end;
    Suspend;

  end;

end;

function TsParallelThread.WorkAmount: Integer;
begin
  FCS.Enter;
  try
    Result := FDataList.Count;
  finally
    FCS.Leave;
  end;
end;

procedure TsParallelThread.Start(AData: IParallelData);
begin
  FCS.Enter;
  try
    FDataList.Add(AData);

  if Suspended then
  begin
    sleep(1);
    Resume;
  end;
  finally                   
    FCS.Leave;
  end;
end;

constructor TsThreadTimer.Create;
begin
  inherited Create(True);
  FEvent := TEvent.Create(nil, True, False, '');
  Resume;
end;

destructor TsThreadTimer.Destroy;
begin
  Terminate;

  FEvent.SetEvent;
  FEvent.Free;
  inherited;
end;

procedure TsThreadTimer.Execute;
begin
  while not Terminated do
  begin
    FEvent.ResetEvent;
    if Assigned(FOnTimer) then
      FOnTimer(self);

    FEvent.WaitFor(100);
  
  end;
end;

constructor TsParallelData.Create;
begin
  inherited;
  FObjectList := TList.Create;
  FStrList := TStringList.Create;
  FAnsiStr1 := '';
  FAnsiStr2 := '';
  FAnsiStr3 := '';
  FInt1 := 0;
  FInt2 := 0;
  FInt3 := 0;
end;

destructor TsParallelData.Destroy;
begin
  FObjectList.Free;
  FStrList.Free;
  inherited;
end;

function TsParallelData.GetAnsiStr1: Ansistring;
begin
  Result := FAnsiStr1;
end;

function TsParallelData.GetAnsiStr2: Ansistring;
begin
  Result := FAnsiStr2;
end;

function TsParallelData.GetAnsiStr3: Ansistring;
begin
  Result := FAnsiStr3;
end;

function TsParallelData.GetInt1: Integer;
begin
  Result := FInt1;
end;

function TsParallelData.GetInt2: Integer;
begin
  Result := Fint2;
end;

function TsParallelData.GetInt3: Integer;
begin
  Result := Fint3;
end;

function TsParallelData.GetObjectList: TList;
begin
  Result := FObjectList;
end;

function TsParallelData.GetStrList: TStrings;
begin
  Result := FStrList;
end;

procedure TsParallelData.SetAnsiStr1(const Value: Ansistring);
begin
  FAnsiStr1 := Value;
end;

procedure TsParallelData.SetAnsiStr2(const Value: Ansistring);
begin
  FAnsiStr2 := Value;
end;

procedure TsParallelData.SetAnsiStr3(const Value: Ansistring);
begin
  FAnsiStr3 := Value;
end;

procedure TsParallelData.SetInt1(const Value: Integer);
begin
  FInt1 := Value;
end;

procedure TsParallelData.SetInt2(const Value: Integer);
begin
  FInt2 := Value;
end;

procedure TsParallelData.SetInt3(const Value: Integer);
begin
  Fint3 := Value;
end;

end.
