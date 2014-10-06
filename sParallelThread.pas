{
  Author: snake
  Date: 2014-09-30
  site: snakelab.cc

  Changelog:

              v0.5 - first release
  2014-10-01  v0.6 - use thread timer instead of TTimer
  2014-10-03  v0.7 - fixed mem leaks, data is freed within thread
  2014-10-06  v0.71 - fixed frozen thread issue

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
    FList: TList;
    FOnError: TsErrorEvent;
    FOnParallelWork: TsParallelEvent;
    FThreadList: TList;
    FTimer: TsThreadTimer;
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
  FDestroying := False;
  FCS := TCriticalSection.Create;
  FList := TObjectList.Create(False);
  FThreadList := TObjectList.Create;
  FThreadList.Add(TsParallelThread.Create(self));
  FTimer := TsThreadTimer.Create;
  FTimer.OnTimer :=  OnTimer;

end;

destructor TsParallelThreadManager.Destroy;
begin
  inherited;
  FDestroying := True;
  FCS.Enter;

  try
    (FList as TObjectList).OwnsObjects := True;
    FList.Clear;

  finally
    FCS.LEave;
  end;
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
  if FDestroying then
    exit;
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
  if FDestroying then
    exit;
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

  FCS := TCriticalSection.Create;
  FData := nil;
end;

destructor TsParallelThread.Destroy;
begin
  inherited;
  FCS.Enter;
  try
    if Assigned(FData) then
      FreeAndNil(FData);
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
begin
  while not Terminated do
  begin
    try
      try
        FCS.Enter;
        try
          if Assigned(FManager.OnParallelWork) then
            FManager.OnParallelWork(FData);
        finally
          FCS.Leave;
        end;
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
        if Assigned(FData) then
          FreeAndNil(FData);
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
    Result := Assigned(FData);
  finally
    FCS.Leave;
  end;
end;

procedure TsParallelThread.Start(AData: TObject);
begin
  FCS.Enter;
  try
    assert(not Assigned(FData), 'fdata');
    FData := AData;

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

end.
