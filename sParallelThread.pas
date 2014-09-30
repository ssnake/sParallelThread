{
  Author: snake
  Date: 2014-09-30
  site: snakelab.cc

  Changelog:

  v0.5 - first release

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

  TsParallelEvent = procedure(AData: TObject) of object;
  TsErrorEvent = procedure(E: Exception) of object;
  TsParallelThreadManager = class;
  TsParallelThread = class(TThread)
  private
    FBusy: Boolean;
    FCS: TCriticalSection;
    FData: TObject;
    FException: Exception;
    FManager: TsParallelThreadManager;
    procedure DoError;
  protected
    procedure Execute; override;
  public
    constructor Create(AManger: TsParallelThreadManager);
    destructor Destroy; override;
    function IsBusy: Boolean;
    procedure Start(AData: TObject);
  end;
  
  TsParallelThreadManager = class(TObject)
  private
    FCS: TCriticalSection;
    FList: TList;
    FOnError: TsErrorEvent;
    FOnParallelWork: TsParallelEvent;
    FThreadList: TList;
    FTimer: TTimer;
    function GetFreeThread: TsParallelThread;
    procedure OnTimer(Sener: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Push(AData: TObject);
    property OnError: TsErrorEvent read FOnError write FOnError;
    property OnParallelWork: TsParallelEvent read FOnParallelWork write
        FOnParallelWork;
  end;



implementation

constructor TsParallelThreadManager.Create;
begin
  inherited;
  FCS := TCriticalSection.Create;
  FList := TList.Create;
  FThreadList := TObjectList.Create;
  FThreadList.Add(TsParallelThread.Create(self));
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 1;
  FTimer.OnTimer :=  OnTimer;
  FTimer.Enabled := True;
end;

destructor TsParallelThreadManager.Destroy;
begin
  inherited;
  FTimer.Enabled := False;
  FTimer.Free;
  FThreadList.Free;
  FList.Free;
  FCS.Free;
end;

function TsParallelThreadManager.GetFreeThread: TsParallelThread;
var
  i: Integer;
begin

  for I := 0 to FThreadList.Count - 1 do
  begin
    Result := TsParallelThread(FThreadList[I]);
    if not Result.IsBusy then
      exit;
  end;


  Result := nil;
end;

procedure TsParallelThreadManager.OnTimer(Sener: TObject);
var
  data: TObject;
  thread: TsParallelThread;
begin
  data := nil;
  thread := GetFreeThread;
  if not Assigned(thread) then
    exit;
  

  FCS.Enter;
  try
    if FList.Count > 0 then
    begin
      data := FList[0];
      FList.Delete(0);

    end;
  finally
    FCS.Leave;
  end;

  if Assigned(data) then
    thread.Start(data);


end;

procedure TsParallelThreadManager.Push(AData: TObject);
begin
  FCS.Enter;
  try
    FList.Add(AData)

  finally
    FCS.Leave;
  end;


end;

constructor TsParallelThread.Create(AManger: TsParallelThreadManager);
begin
  inherited Create(True);
  FManager := AManger;
  FBusy := False;
  FCS := TCriticalSection.Create;
end;

destructor TsParallelThread.Destroy;
begin
  inherited;
  FCS.Free;
end;

procedure TsParallelThread.DoError;
begin
  FManager.OnError(FException);  
end;

procedure TsParallelThread.Execute;
begin
  while not Terminated do
  begin
    FCS.Enter;
    try
      FBusy := True;

    finally
      FCS.Leave;
    end;
    try
      try
        if Assigned(FManager.OnParallelWork) then
          FManager.OnParallelWork(FData);
      except
        on E: exception  do
        begin
          FException := E;
          if Assigned(FManager.OnError) then
            Synchronize(DoError);
        end;


      end;

    finally
      FCS.Enter;
      try
        FBusy := False;

      finally
        FCS.Leave;
      end;

    end;
    Suspend;

  end;

end;

function TsParallelThread.IsBusy: Boolean;
begin
  FCS.Enter;
  try
  Result := FBusy;
  finally
    FCS.Leave;
  end;
end;

procedure TsParallelThread.Start(AData: TObject);
begin
  FData := AData;
  if Suspended then
    Resume;
end;

end.