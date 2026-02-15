10 REM ---- bubble-verse

20 DT = $BFD0
21 RG = $BFD1


50 CLS          
60 PRINT "LT6502 Bubbleverse"
61 PRINT "(VALUE) is usual value"
62 PRINT "[VALUE] is limits for value if applicable"
65 T = 0
67 INPUT "Start Iteration (0)";T
68 INPUT "T Increment[>0] (1)";TI
69 IF TI > 0 THEN GOTO 71
70 TI = 1
71 INPUT "LOOPS [1-200] (200)";N
72 INPUT "Stepsize[>0] (1)";ST
73 IF ST > 0 GOTO 75
74 ST = 1
75 CLS

80 OUTK "T="
81 OUTK T

110 REM N = 200
120 TA = (2*PI)/235
130 R = TA / 235

140 X = 0 
150 V = 0 
160 REM T = 0 
170 HS = 200   : REM this uses width of screen
175 VS = 120
180 GW = 400
190 GH = 240

200 MODE 1     : REM Switch to graphics mode


300 REM -- MAIN LOOP
320 FOR I = 0 TO N STEP ST
330 FOR J = 0 TO N STEP ST
340 U = SIN(I+V) + SIN((R * I) + X)
350 V = COS(I+V) + COS((R * I) + X)
360 X = U + T
370 GOSUB 1000

380 PX = INT(GW+(U*HS))
381 PY = INT(GH+(V*VS))
385 PLOT PX,PY,PC 

390 NEXT J
400 NEXT I
410 REM T = T + (1/N)
410 T = T + TI
420 OUTK "T="
425 OUTK T
430 BEEP 100,50
450 GOTO 300 


1000 REM -- CALC COLOURS
1020 PR = 1+INT(I / (N/7))
1021 IF PR < 8 THEN GOTO 1030
1022 PR = 7

1030 PG = INT(J / (N/8))
1031 IF PG < 8 THEN GOTO 1040
1032 PG = 7

1040 PB = 2
1060 PC = PR << 5
1070 TP = PG << 2
1080 PC = PC + TP + PB
1999 RETURN


