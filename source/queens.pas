program queens;

const _ESC = #27;
      _CLS = #26;
      _HOME = #30;
      _REVERSE = #27'B0';
      _PLAIN = #27'C0';
      _BLINK = #27'B2';
      _NOBLINK = #27'C2';
      _UNDERLINE = #27'B3';
      _NOUNDERLINE = #27'C3';
      _DARK = #27'B1';
      _LIGHT = #27'C1';
      _BEEP = #7;

      _STRLENMAX = 80;

type stringvar=string[_STRLENMAX];
     charset=set of char;
     coord=1..8;
     casella = RECORD
       busy  : boolean;
       forbid: boolean;
     END;
     Tboard  = ARRAY [coord, coord] of casella;
     Tsoluz  = ARRAY [coord] of char;
     datastr = string[10];
     entry   = record
       config: Tsoluz;
       name: stringvar;
     end;
     Tstream = TEXT;
     cmdtype = (ERR, NULLO, CELL, UNDO, REDO, CLEAR, QUIT, PR, PRALL, CLALL, QUIT2);

var board  : Tboard;
    scelta : integer;

{ ----------------------------------------------------------------------------
  VDCregWr, VDCregRdm, CursorFlash:
  Copyright (C) Ralph Schlichtmeier, Markt & Technik Verlag AG }

type switch = (on, off, slow, fast, no);

procedure VDCregWr (reg, wert: byte);
begin inline ($01/$00/$D6/$3A/reg/$ED/$79/$ED/$78/$17/$D2/*-5/$0C/$3A/wert/$ED/$79) end;

function VDCregRd (reg: byte): byte;
begin inline ($01/$00/$D6/$3A/reg/$ED/$79/$ED/$78/$17/$D2/*-5/$0C/$ED/$68/$26/$00/$C9) end;

procedure CursorFlash (cf : switch);
var mode : BYTE;
begin
  case cf of
    off  : mode := VDCregRd(10) AND 191 OR 32;
    slow : mode := VDCregRd(10) OR 96;
    fast : mode := VDCregRd(10) AND 223 OR 64;
    no   : mode := VDCregRd(10) AND 159
  else
    mode := VDCregRd(10)
  end;
  VDCregWr(10, mode)
end;
{ ---------------------------------------------------------------------------- }

procedure append(var f:text);
{ Append: Copyright (C) Werner Cirsovius, Version 1.0 July 1988 }
begin
  inline (
  {0000}  $22/*+139/$11/$0c/$00/$19/$e5/$22/*+133/$11/$24/$00/$19/$22/
  {0010}  *+128/$e1/$cd/*+108/$0e/$0f/$cd/*+94/$20/$54/$2a/*+114/
  {0020}  $eb/$0e/$1a/$cd/$05/$00/$0e/$23/$cd/*+78/$20/$3f/$11/$21/$00/
  {0030}  $2a/*+93/$19/$4e/$23/$5e/$23/$56/$79/$b2/$b3/$28/$22/$0d/$f2/
  {0040}  *+3/$1b/$72/$2b/$73/$2b/$71/$0e/$21/$cd/*+44/$20/$1d/$2a/
  {0050}  *+64/$0e/$00/$06/$80/$3e/$1a/$be/$ca/*+6/$23/$0c/$10/$f8/
  {0060}  $2a/*+43/$36/$40/$23/$23/$71/$3e/$00/$18/$07/$3e/$02/$c3/*+4/
  {0071}  $3e/$01/$32/$d0/$00/$c9/$ed/$5b/*+21/$cd/$05/$00/$b7/$c9/$11/
  {0081}  $0c/$00/$19/$06/$18/$36/$00/$23/$10/$fb/$c9/$00/$00/$00/$00/$00/
  {0091}  $00);
end;

procedure hidecursor;
begin
 { cursorflash(off); }
   write(#27'C4');
   end;

procedure showcursor;
begin
 { cursorflash(fast); }
   write(#27'B4');
end;

function soluz2string(soluz:Tsoluz):stringvar;
var result:stringvar;
    i:coord;
begin
  result:='';
  for i:=1 to 8 do result:=result+soluz[i];
  soluz2string:=result;
end;

procedure string2soluz(s:stringvar; var soluz:Tsoluz);
var i:integer;
begin
  for i:=1 to 8 do soluz[i]:=s[i];
end;

function readkey(validkeys:charset):char;
var ch:char;
begin
  repeat read(kbd,ch) until ch in validkeys;
  readkey := ch;
end;

function itoa(i:integer):stringvar;
var s:stringvar;
begin
  str(i,s);
  itoa:=s;
end;

function lastpos(s:stringvar;c:char):integer;
var i,p:integer;
begin
  p:=0;
  if length(s)>0 then
     for i:=1 to length(s) do
       if s[i]=c then p:=i;
  lastpos:=p;
end;

procedure initboard(var board:Tboard);
var i,j:coord;
begin
  for i:=1 to 8 do
    for j:=1 to 8 do begin
      board[i,j].busy := false;
      board[i,j].forbid := false;
    end;
end;

function allowed(var board:Tboard;x,y:coord):boolean;
begin
  allowed := not board[x,y].forbid;
end;

function countavailable(var board:Tboard):integer;
var result,i,j:integer;
begin
  result:=0;
  for i:=1 to 8 do
    for j:=1 to 8 do
      if allowed(board,i,j) then result:=result+1;
  countavailable:=result;
end;

procedure drawboard;
var i,j,k:integer;
begin
  gotoxy(1,1);
  write(_REVERSE);
  for i:=1 to 8 do begin
    for k := 1 to 3 do begin
      for j := 1 to 8 do begin
         if (i+j) mod 2 = 0 then write(_DARK) else write(_LIGHT);
         write('       ');
      end;
      if (i<8) or (k<3) then writeln
    end;
  end;
  for i:=1 to 8 do begin
    if i mod 2 = 1 then write(_DARK) else write(_LIGHT);
    gotoxy((i-1)*7+1,1); write(i);
    gotoxy(1,(i-1)*3+1); write(i);
  end;
  write(_PLAIN,_LIGHT);
end;

procedure clearqueen(i,j:integer);
begin
  if (i+j) mod 2 = 0 then write(_DARK) else write(_LIGHT);
  write(_REVERSE);
  gotoxy((j-1)*7+2,(i-1)*3+1); write('     ');
  gotoxy((j-1)*7+2,(i-1)*3+2); write('     ');
  gotoxy((j-1)*7+2,(i-1)*3+3); write('     ');
  write(_PLAIN,_LIGHT);
end;

procedure drawqueen(i,j:integer);
begin
  if (i+j) mod 2 = 0 then write(_DARK) else write(_LIGHT);
  write(_REVERSE);
  gotoxy((j-1)*7+2,(i-1)*3+1); write(' \|/ ');
  gotoxy((j-1)*7+2,(i-1)*3+2); write(' |Q| ');
  gotoxy((j-1)*7+2,(i-1)*3+3); write('-+-+-');
  write(_PLAIN,_LIGHT);
end;

procedure clearboard(var board:Tboard);
var x,y:coord;
begin
  for x:=1 to 8 do
    for y:=1 to 8 do
      if board[x,y].busy then clearqueen(y,x);
end;

procedure renderboard(var board:Tboard);
var x,y:coord;
begin
  for x:=1 to 8 do
    for y:=1 to 8 do
      if board[x,y].busy then drawqueen(y,x);
end;

function repl(a:stringvar;n:integer):stringvar;
var i:integer;
    b:stringvar;
begin
  b:='';
  if n>0 then
    for i:=1 to n do b:=b+a;
  repl:=b;
end;

procedure plotbox(x1,y1,x2,y2:integer;h,v:boolean);
var i,j:integer;
begin
  write(_LIGHT,_REVERSE);
  if v then
    for i:=1 to 2 do
      for j:=y1 to y2 do begin
        if i=1 then gotoxy(x1,j) else gotoxy(x2,j);
        write(' ');
      end;
  if h then begin
     gotoxy(x1,y1); write(repl(' ',x2-x1+1));
     gotoxy(x1,y2); write(repl(' ',x2-x1+1));
  end;
  write(_PLAIN);
end;

procedure center(y:integer;col:stringvar;s:stringvar);
begin
  gotoxy((80-length(s)) div 2 + 2,y);write(col,s);
end;

procedure pulisci(a,b:integer);
var i:integer;
    s:stringvar;
begin
  s:=repl(' ',72);
  for i:=a to b do begin
    gotoxy(5,i);write(s);
  end;
end;

procedure initialize;
begin
  scelta:=1;
end;

procedure introscreen;
begin
  if scelta=1 then begin
     clrscr;
     plotbox(3,2,78,23,true,true);
     plotbox(4,2,77,23,false,true);
  end else
     pulisci(3,22);

  gotoxy(16,4); write(_DARK);
  write('   ',_REVERSE,'    ',_PLAIN,'   ',_REVERSE,'  ',
  _PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'      ',_PLAIN,
  '  ',_REVERSE,'      ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,
  '   ',_REVERSE,'    ');

  gotoxy(16,5);
  write(_PLAIN,'  ',_REVERSE,'  ',
  _PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,
  '  ',_REVERSE,'  ',_PLAIN,'      ',_REVERSE,'  ',_PLAIN,'      ',_REVERSE,'   ',_PLAIN,
  ' ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ');

  gotoxy(16,6);
  write(_PLAIN,'  ',_REVERSE,'  ',
  _PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,
  '  ',_REVERSE,'  ',_PLAIN,'      ',_REVERSE,'  ',_PLAIN,
  '      ',_REVERSE,'      ',_PLAIN,'  ',_REVERSE,'  ');

  gotoxy(16,7);
  write(_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,
  '  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',
  _PLAIN,'  ',_REVERSE,'    ',_PLAIN,'    ',_REVERSE,'    ',_PLAIN,'    ',_REVERSE,'  ',_PLAIN,' ',
  _REVERSE,'   ',_PLAIN,'   ',_REVERSE,'    ');

  gotoxy(16,8);
  write(_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',
  _REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',
  _PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'      ',_REVERSE,'  ',_PLAIN,'      ',
  _REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',
  _PLAIN,'      ',_REVERSE,'  ');

  gotoxy(16,9);
  write(_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',
  _REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',
  _REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'      ',_REVERSE,'  ',_PLAIN,'      ',_REVERSE,'  ',
  _PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',
  _REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ');

  gotoxy(16,10);
  write(_PLAIN,'   ',_REVERSE,'    ',_PLAIN,'    ',_REVERSE,'    ',
  _PLAIN,'   ',_REVERSE,'      ',_PLAIN,'  ',
  _REVERSE,'      ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'  ',_REVERSE,'  ',_PLAIN,'   ',_REVERSE,'    ');

  gotoxy(16,11);
  write(_PLAIN,'     ',_REVERSE,'    ',_LIGHT);

  center(13,_PLAIN,'Written by Francesco Sblendorio');
end;

procedure selectionscreen;
var c:char;
    m,err:integer;
begin
  center(15,_PLAIN,'Make your choice');
  m:=0;
  while (m<1) or (m>4) do begin
    center(17,_PLAIN,'1. Start game                 ');
    center(18,_PLAIN,'2. Display found solutions    ');
    center(19,_PLAIN,'3. About Queens               ');
    center(20,_PLAIN,'4. Exit to CP/M command prompt');
    c:=readkey(['1','2','3','4',#13,#27,#3]);
    val(c,m,err);
    if (c=#13) then m:=1;
    if (c=#27) or (c=#3) then m:=4;
  end;
  scelta:=m;
end;

procedure esci;
var c:char;
begin
  pulisci(16,22);
  center(18,_PLAIN,'Are you sure you want to exit?');
  center(20,_PLAIN,'(Y/N)');
  c := readkey(['y','Y','n','N','0','1',#27,#3]);
  case c of
    'y','Y','1': scelta:=4;
    'n','N','0',#27,#3: scelta:=-1;
  end;
end;

procedure infoscreen;
var c:char;
begin
  pulisci(3,22);
  center(4,_REVERSE,'                 ');
  center(5,_REVERSE,'   Q U E E N S   ');
  center(6,_REVERSE,'                 ');
  center(8,_PLAIN,'written by');
  center(9,_PLAIN,'Francesco Sblendorio');
  center(10,_UNDERLINE,'http://www.sblendorio.eu');
  center(12,_NOUNDERLINE,'(C) 1996 MS-DOS version     (C) 2015 CP/M version');
  gotoxy(7,15); write(_DARK,'The ',_LIGHT,'eight queen puzzle',_DARK,' is the problem of placing eight chess queens');
  gotoxy(7,17); write('on an 8x8 chessboard so that no two queens threaten each other.');
  gotoxy(7,19); write('Thus,  a solution requires that no two queen share same row, column');
  gotoxy(7,21); write('or diagonal.');
  write('                     (Wikipedia - ',_LIGHT,_UNDERLINE,'http://goo.gl/W1XCXZ',_DARK,_NOUNDERLINE,')');
  write(_PLAIN);
  read(kbd,c);
end;

procedure exitscreen;
begin
  write(_PLAIN,_NOBLINK,_LIGHT,_NOUNDERLINE);
  { backgroundcolor(black); }
  clrscr;
end;

procedure drawplaycommands;
begin
  gotoxy(64,02); write(_LIGHT,'= QUEENS =');
  gotoxy(59,04); write('Enter row and column:');
  gotoxy(59,05); write('>');
  gotoxy(59,07); write('Commands:');
  gotoxy(59,08); write(_LIGHT,_UNDERLINE,'U',_NOUNDERLINE,_DARK,'ndo');
  gotoxy(59,09); write(_LIGHT,_UNDERLINE,'R',_NOUNDERLINE,_DARK,'edo');
  gotoxy(59,10); write(_LIGHT,_UNDERLINE,'C',_NOUNDERLINE,_DARK,'lear');
  gotoxy(59,11); write(_DARK,'e',_LIGHT,_UNDERLINE,'X',_NOUNDERLINE,_DARK,'it');
  gotoxy(59,13); write(_LIGHT,'Messages:');
  gotoxy(59,14); write(_BLINK,'_',_NOBLINK);
end;

procedure drawviewcommands;
begin
  gotoxy(64,02); write(_LIGHT,'= QUEENS =');
  gotoxy(59,04); write('View solution N.');
  gotoxy(59,06); write('Found by:');
  gotoxy(59,07); write(_REVERSE,_DARK,'                    ',_PLAIN,_LIGHT);
  gotoxy(59,09); write('Commands:');
  gotoxy(59,10); write('--------------------');
  gotoxy(59,11); write(_LIGHT,'SPACE',_DARK,'  Next solution');
  gotoxy(59,12); write(_LIGHT,'ENTER',_DARK,'  Back to first');
  gotoxy(59,13); write(_LIGHT,' ESC ',_DARK,'  Main menu');
end;

procedure displaymsg(s1:stringvar);
const rowstart=14;
      colstart=59;
begin
  gotoxy(colstart,rowstart); write(_DARK,s1,_LIGHT);
  write(_BLINK,'_',_NOBLINK); if length(s1)<21 then clreol;
end;

procedure getplaycommand(var tp:cmdtype; var cx,cy:coord);
var ch:char;
    kp:boolean;
    primotasto:boolean;
begin
  primotasto:=true;
  repeat
    tp:=err;
    ch := readkey(['1','2','3','4','5','6','7','8',#27,#3,#127,'U','u','R','r','C','c','X','x',#8]);
    ch := upcase(ch);
    displaymsg(''); gotoxy(60,5);
    case ch of
  #127,#8,'U': tp := UNDO;
          'R': tp := REDO;
          'C': tp := CLEAR;
   #3,#27,'X': tp := QUIT;
     '1'..'8': if primotasto then begin
                  primotasto:=false;
                  tp:=NULLO;
                  cy:=ord(ch)-48;
                  write(cy:0,'- ',#8);
               end else begin
                  tp:=CELL;
                  cx:=ord(ch)-48;
               end;
    end;
    if (tp=ERR) then begin
      displaymsg('ERROR: Invalid key');
      write(_BEEP);
    end;
  until (tp<>NULLO) and (tp<>err);
end;

procedure putpiece(var board:Tboard; x,y:coord);
var px,py,delta:coord;
begin
  board[x,y].busy:=true;
  for px:=1 to 8 do board[px,y].forbid:=true;
  for py:=1 to 8 do board[x,py].forbid:=true;
  if x<y then delta:=x-1 else delta:=y-1; { delta=min(x-1,y-1) }
  px:=x-delta; py:=y-delta;
  while (px<=8) and (py<=8) do begin
    board[px,py].forbid:=true;
    px:=px+1;
    py:=py+1;
  end;
  if (8-x)<(y-1) then delta:=8-x else delta:=y-1; { delta=min(8-x,y-1) }
  px:=x+delta; py:=y-delta;
  while (px>=1) and (py<=8) do begin
    board[px,py].forbid:=true;
    px:=px-1;
    py:=py+1;
  end;
end;

procedure arraytomatrix(var soluz:Tsoluz;var board:Tboard);
var i:coord;
begin
  initboard(board);
  for i:=1 to 8 do putpiece(board,ord(soluz[i]),i);
end;

procedure clearinput;
begin
  gotoxy(60,5); write('    ');
end;

procedure startgame(var board:Tboard);
type redotype = record avail:boolean;
                       cx,cy:coord;
                end;
     undotype = record avail:boolean;
                       matrix:Tboard;
                       cx,cy:coord;
                end;
var x,y:coord;
    count:integer;
    item,itmp:entry;
    strconfig:stringvar;
    exc:integer;
    stream:Tstream;
    trovato:boolean;
    i:integer;
    strnum:string[3];
    iores:integer;
    ch:char;
    tp:cmdtype;
    xredo:redotype;
    xundo:undotype;
begin
  initboard(board);
  xundo.avail := false;
  xredo.avail := false;
  clrscr;
  drawboard;
  drawplaycommands;
  count := 0;
  gotoxy(60,5); write(_LIGHT,'    ');
  showcursor;
  repeat
    gotoxy(60,5);
    getplaycommand(tp,x,y);
    if tp=CELL then begin
      gotoxy(60,5);
      write(y:0,'-',x:0);
      if allowed(board,x,y) then begin
        xundo.avail:=true;
        xundo.matrix:=board;
        xundo.cx:=x; xundo.cy:=y;
        xredo.avail:=false;
        xredo.cx:=x; xredo.cy:=y;
        putpiece(board,x,y);
        count:=count+1;
        item.config[y]:=chr(x);
        drawqueen(y,x);
        if (count<8) and (countavailable(board)=0) then begin
           displaymsg('WARN: can''t continue');
           write(_BEEP);
        end else if countavailable(board) < (8-count) then begin
           displaymsg('WARN: can''t win');
           write(_BEEP);
        end
      end else begin
        displaymsg('ERROR: forbidden cell');
        write(_BEEP);
      end
    end else if tp=UNDO then begin
      clearinput;
      if xundo.avail then begin
         count:=count-1;
         xundo.avail:=false;
         xredo.avail:=true;
         board:=xundo.matrix;
         clearqueen(xundo.cy,xundo.cx);
         displaymsg('UNDO: done');
      end else begin
         displaymsg('ERROR: can''t UNDO');
         write(_BEEP);
      end;
    end else if tp=REDO then begin
      clearinput;
      if xredo.avail then begin
         xredo.avail:=false;
         xundo.avail:=true;
         xundo.matrix:=board;
         xundo.cx:=xredo.cx;
         xundo.cy:=xredo.cy;
         putpiece(board,xredo.cx,xredo.cy);
         count:=count+1;
         drawqueen(xredo.cy,xredo.cx);
         displaymsg('REDO: done');
      end else begin
         displaymsg('ERROR: can''t REDO');
         write(_BEEP);
      end;
    end else if tp=CLEAR then begin
      xredo.avail:=false;
      xundo.avail:=false;
      clearboard(board);
      initboard(board);
      clearinput;
      count:=0;
      displaymsg('CLEAR: done');
      write(_BEEP);
    end;
  until (count=8) or (tp=QUIT);
  hidecursor;
  if tp<>QUIT then begin
     assign(stream,'QUEENS.DAT');
     {$I-}
     reset(stream);
     {$I+}
     iores:=IOResult;
     if (iores=1) or (iores=2) then begin { File Not Found }
        {$I-} close(stream); {$I+}
        displaymsg('You won! '+_BLINK+'Solution #1'+_NOBLINK);
        gotoxy(59,16); write('Write down your name');
        gotoxy(59,17); write(_REVERSE,_DARK,'                    ');
        showcursor;
        gotoxy(59,17); readln(item.name);
        if item.name='' then begin write(_PLAIN,_LIGHT); close(stream); exit; end;
        hidecursor;
        for i:=1 to length(item.name) do item.name[i]:=upcase(item.name[i]);
        gotoxy(59,17); write(item.name,_PLAIN,_LIGHT);
        displaymsg(_BLINK+'Please wait...'+_NOBLINK);
        {$I-}
        rewrite(stream);
        writeln(stream,item.name);
        writeln(stream,soluz2string(item.config));
        close(stream);
        {$I+}
        displaymsg('');
     end else if iores=0 then begin { Solutions file already exists }
        trovato:=false;
        count:=0;
        while (not eof(stream)) and (not trovato) do begin
          count:=count+1;
          readln(stream,itmp.name);
          readln(stream,strconfig);
          string2soluz(strconfig,itmp.config);
          if strconfig=soluz2string(item.config) then trovato:=true;
        end;
        if trovato then begin { Solution already known }
          close(stream);
          str(count:0,strnum);
          displaymsg('Known solution #'+strnum);
          gotoxy(59,16); write(_LIGHT,'Solution found by:');
          gotoxy(59,17); write(_REVERSE,_DARK,'                    ');
          gotoxy(59,17); write(itmp.name,_PLAIN,_LIGHT);
        end else begin { New solution }
          str(count+1:0,strnum);
          displaymsg(_BLINK+'New'+_NOBLINK+' solution #'+strnum);
          gotoxy(59,16); write('Write down your name');
          gotoxy(59,17); write(_REVERSE,_DARK,'                    ');
          showcursor;
          gotoxy(59,17); readln(item.name);
          if item.name='' then begin write(_PLAIN,_LIGHT); close(stream); exit; end;
          hidecursor;
          for i:=1 to length(item.name) do item.name[i]:=upcase(item.name[i]);
          gotoxy(59,17); write(item.name,_PLAIN,_LIGHT);
          displaymsg(_BLINK+'Please wait...'+_NOBLINK);
          {$I-}
          close(stream);
          append(stream);
          writeln(stream,item.name);
          writeln(stream,item.config);
          close(stream);
          {$I+}
          displaymsg('');
        end
     end else begin { Generic I/O Error }
        str(iores,strnum);
        displaymsg('I/O Error #'+strnum);
     end;
     gotoxy(59,19); write('Press any key');
     repeat until keypressed;
  end;
end;

procedure showarchive;
var tot,cur:integer;
    ch:char;
    stream:Tstream;
    iores:integer;
    strconfig:stringvar;
    item:entry;
    board:Tboard;
begin
  scelta:=1;
  initboard(board);
  clrscr;
  assign(stream,'QUEENS.DAT');
  {$I-} reset(stream); {$I+}
  iores:=ioresult;
  if iores<>0 then begin { File not found }
     {$I-} close(stream); {$I+}
     if (iores=1) or (iores=2) then
       center(11,_NOBLINK,'No solution saved. Press any key to return to main menu')
     else
       center(11,_NOBLINK,'Generic I/O error occurred. Press any key to return to main menu');
     write(_NOBLINK);
     repeat until keypressed;
     exit;
  end;
  drawboard;
  drawviewcommands;
  showcursor;
  tot:=0;
  while not eof(stream) do begin
    readln(stream,strconfig);
    tot:=tot+1;
  end;
  tot:=tot div 2;
  reset(stream);
  cur:=0;
  ch:=' ';
  while true do begin
    if (cur<tot) and (ch<>'x') then begin
      cur:=cur+1;
      readln(stream,item.name);
      readln(stream,strconfig);
      gotoxy(75,4);clreol;write(_LIGHT,cur:0,'/',tot:0);
      string2soluz(strconfig,item.config);
      arraytomatrix(item.config,board);
      renderboard(board);
      gotoxy(59,7);write(_REVERSE,_DARK,'                    ');
      gotoxy(59,7);write(item.name,_PLAIN,_LIGHT);
    end;
    ch:=readkey([#32,#13,#27,#3]);
    case ch of
      #3,#27: begin {$I-} close(stream); {$I+} exit; end;
      #13:    if cur>1 then begin
                clearboard(board);
                cur:=0;
                close(stream);
                reset(stream);
              end else ch:='x';
      #32:    if cur<tot then begin
                clearboard(board);
              end;
    end;
  end;
end;

begin
  hidecursor;
  {write(#27#27#27#33,_PLAIN,_NOBLINK,_LIGHT,_NOUNDERLINE);}
  initialize;
  scelta:=1;
  repeat
    if scelta=-1 then pulisci(16,21) else introscreen;
    selectionscreen;
    case scelta of
      1: startgame(board);
      2: showarchive;
      3: infoscreen;
      4: esci;
    end;
  until scelta=4;
  exitscreen;
  write(_PLAIN);showcursor;
end.
