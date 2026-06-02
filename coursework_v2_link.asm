.model 	small
.stack	200h

; Координаты
CIRCLE_X  EQU 310
CIRCLE_Y  EQU 300
CIRCLE_R   EQU 110

RECT_X1    EQU 230
RECT_Y1    EQU 240
RECT_X2    EQU 390
RECT_Y2    EQU 360

Flags_X1 EQU 85
Flags_Y1 EQU 25
Flags_X2 EQU 235
Flags_Y2 EQU 175

Vert_CROSS_X1 EQU 140
Vert_CROSS_Y1 EQU 50
Vert_CROSS_X2 EQU 180
Vert_CROSS_Y2 EQU 150

Horiz_CROSS_X1 EQU 110
Horiz_CROSS_Y1 EQU 80
Horiz_CROSS_X2 EQU 210
Horiz_CROSS_Y2 EQU 120


; Цвета
COL_RED    EQU 4
COL_GREEN EQU 2
COL_YELLOW EQU 14
COL_WHITE  EQU 15
COL_BLACK  EQU 0
COL_PINK EQU 13

.data
    ; для круга
	eror dw ?
	x dw ?
	y dw ?
	x0 dw ?
	y0 dw ?
	delta dw ?
	radius dw ?

    COLOR dw ?

    ;локальные переменные функции line Брезенхейма
    DIAGONAL_Y_INCREMENT dw ?
    DIAGONAL_X_INCREMENT dw ?
    SHORT_DISTANCE dw ?
    STRAIGHT_X_INCREMENT dw ?
    STRAIGHT_Y_INCREMENT dw ?
    STRAIGHT_COUNT dw ?
    DIAGONAL_COUNT dw ?


        ; ---- ДЛЯ ВЫВОДА ТЕКСТА ----
    num_buf     db 12 dup(0)      ; буфер для преобразования числа
    str_sc      db 'Scirc=',0
    str_sr      db 'Srect=',0
    area_circle dw ?               ; вычисленная площадь круга
    area_rect   dw ?               ; вычисленная площадь прямоугольника

    ; Переменные для процедур вывода (глобальные, используются в текущей реализации)
    txt_col     db ?
    txt_row     db ?
    txt_attr    db ?
    pn_col      db ?
    pn_row      db ?
    pn_attr     db ?
    pn_num      dw ?
.code
put_pixel proc 
	mov bh, 0
	mov Ah, 0Ch		;Функция отрисовки точки
	int 10h			;Нарисовать точку
    ret
put_pixel endp


ClearScreen PROC
    push es
    push ax
    push cx
    push di
    mov ax, 0A000h
    mov es, ax
    mov di, 0
    mov cx, 640*480
    mov al, 0
    rep stosb
    pop di
    pop cx
    pop ax
    pop es
    ret
ClearScreen ENDP



;Алгоритм Брезенхема реализация
line_brezenhem proc  

    push bp     ; сохраняем статическое начало стека с стеке  2 байта
    mov  bp, sp ; перезаписываем внего первоначальное положение конца стека припуше sp сдвигается так что лучше пользоватся bp
    ;надо переписать под использование вместо переменных stack так как это удобнее и понятно
    push ax
    push bx
    push cx
    push dx
    push si
    push di



    ; параметры: [bp+4] = START_X, [bp+6] = START_Y, [bp+8] = END_X, [bp+10] = END_Y, [bp+12] = COLOR
    ;mov ax, [bp+4]   ; START_X
    ;mov bx, [bp+6]   ; START_Y
    ;mov cx, [bp+8]   ; END_X
    ;mov dx, [bp+10]  ; END_Y
    ;mov si, [bp+12]  ; color (word, но нужен только младший байт)




;если координаты начала и конца совпадают
    mov ax, [bp+4] ;START_X      обозначения координат для (x1,y1) и (x2,y2)
    cmp ax, [bp+8];END_X  
    jnz short DRAW
    mov ax, [bp+6];START_Y
    cmp ax, [bp+10]; END_Y
    jnz short DRAW

    mov dx,ax ; y1
    mov cx,[bp+4];START_X ; x1
    mov al, byte ptr [bp+12];COLOR
    call put_pixel ;вызов функции вывода одной точки
    jmp LINE_FINISHED

    DRAW:
    ;установка нач-ч инкрементов для каждой точки
        mov cx, 1 ;инкремент для оси х 
        mov dx, 1 ;инкремент для оси y это SignA
        ;вычисление вертикальной дистанции
        mov di, [bp+10]; END_Y di это A = Y2 - Y1 вычитаем координату начальной  точки из координаты конечно
        sub di, [bp+6];START_Y
        jge KEEP_Y; вперед если наклон < 0
        neg dx ; иначе инкремент SignA = -1 
        neg di ; в дистанции должна быть  >0


    KEEP_Y:
        mov DIAGONAL_Y_INCREMENT, dx


        ;вычисление горизонтальной дистанции
        mov si, [bp+8]   ; END_X di это B = Y2 - Y1 вычитаем координату начальной  точки из координаты конечно
        sub si, [bp+4] ;START_X
        jge KEEP_X; вперед если наклон < 0
        neg cx ; иначе инкремент SignB = -1 
        neg si ; в дистанции должна быть  >0


    KEEP_X:
        mov DIAGONAL_X_INCREMENT, cx


    ;определяем горизонтальной или вертикальны прямые сегменты
    cmp si,di ;горизонтальные длинее? |A| < |B|?
    jge HORT_SEG ;если да, то вперед f = f+A*SignA
    mov cx,0 ;иначе для прямых х не меняется 
    xchg si,di ;помещаем большее в сх
    jmp SAVE_VALUE; сохраняем значение
    
    HORT_SEG:
        mov dx, 0 ;теперь для прямых не менятся Y
    
    SAVE_VALUE:
        mov SHORT_DISTANCE, di ; меньшее растояние 
        mov STRAIGHT_X_INCREMENT, cx ; один из них 0
        mov STRAIGHT_Y_INCREMENT, dx ; а в другой -1
        mov ax, SHORT_DISTANCE ;меньшее растояние в ax
        shl ax,1 ;удваиваем его shl - инструкция  выполняющая логический сдвиг влево содержимого регистра ax на 1 бит. что посути умножение на 2 как C

        mov STRAIGHT_COUNT,ax
        sub ax,si ;2* меньшее - большее
        mov bx, ax ;запоминаем как счетчик цикла 
        sub ax,si ;2*меньшее - 2*большее
        mov DIAGONAL_COUNT, ax ; запоминаем

        ;подготовка к выводу линии
        mov cx, [bp+4]   ; START_X начальная координата х
        mov dx, [bp+6]   ; START_Y началаьная координат y
        inc si
        MOV  AL, byte ptr [bp+12];COLOR
        

        ;теперь выводим линию
    MAINLOOP:
        dec si; счетчик для большего расстояния
        jz LINE_FINISHED; вывод последней точки
        push bx
        call put_pixel
        pop bx 
    SKIP: 
        cmp bx,0 ; Если ВХ < 0 то прямой сегменты
        jge DIAGONAL_LINE; иначе диагональный сегмент
        ;выводим прямые сегменты
        add cx, STRAIGHT_X_INCREMENT; определяем инкременты по осям
        add dx, STRAIGHT_Y_INCREMENT; 
        add bx, STRAIGHT_COUNT; фактор выравнивания
        
        jmp short MAINLOOP; на след точку

    ;выводим диагональный сегмент
    DIAGONAL_LINE:
        add cx, DIAGONAL_X_INCREMENT ;определяем инкременты по осям
        add dx, DIAGONAL_Y_INCREMENT 
        add bx, DIAGONAL_COUNT;  фактор выравнивания
        
        jmp short MAINLOOP; на след точку
    
    LINE_FINISHED:
        ; эпилог:
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        pop bp
        ret 10
line_brezenhem endp


drawCircle proc
        mov x, 0
	mov ax, radius
        mov y, ax
        mov delta, 2
	mov ax, 2
	mov dx, 0
	imul y
	sub delta, ax
	mov eror, 0
	jmp ccicle
finally: ret
ccicle:
	mov ax, y
	cmp ax, 0
	jl  finally
	mov cx, x0
	add cx, x
	mov dx, y0
	add dx, y

    mov al, COL_PINK

	call put_pixel
        mov cx, x0
	add cx, x
	mov dx, y0
	sub dx, y
	call put_pixel
	mov cx, x0
	sub cx, x
	mov dx, y0
	add dx, y
	call put_pixel
	mov cx, x0
	sub cx, x
	mov dx, y0
	sub dx, y
	call put_pixel
	mov ax, delta
	mov eror, ax
	mov ax, y
	add eror, ax
	mov ax, eror
	mov dx, 0
	mov bx, 2
	imul bx
	sub ax, 1
	mov eror, ax
	cmp delta, 0
	jg sstep
	je sstep
	cmp eror, 0
	jg  sstep
	inc x
	mov ax, 2
	mov dx, 0
	imul x
	add ax, 1
	add delta, ax
        jmp ccicle
sstep:
	mov ax, delta
	sub ax, x
	mov bx, 2
	mov dx, 0
	imul bx
	sub ax, 1
	mov eror, ax
	cmp delta, 0
	jg tstep
	cmp eror, 0
	jg tstep
	inc x
	mov ax, x
	sub ax, y
	mov bx, 2
	mov dx, 0
	imul bx
	add delta, ax
        dec y
	jmp ccicle
tstep:
	dec y
        mov ax, 2
	mov dx, 0
	imul y
	mov bx, 1
	sub bx, ax
	add delta, bx
	jmp ccicle
drawCircle endp


DrawRectangle proc
    push bp
    mov  bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Достаём параметры из стека
    mov  ax, [bp+4]   ; x1
    mov  bx, [bp+6]   ; y1
    mov  cx, [bp+8]   ; x2
    mov  dx, [bp+10]  ; y2
    mov  si, [bp+12]  ; color

    ; Верхняя сторона (y = y1, x от x1 до x2)
    push si
    push bx          ; y1
    push cx          ; x2
    push bx          ; y1
    push ax          ; x1
    call line_brezenhem

    ; Нижняя сторона (y = y2, x от x1 до x2)
    push si
    push dx          ; y2
    push cx          ; x2
    push dx          ; y2
    push ax          ; x1
    call line_brezenhem

    ; Левая сторона (x = x1, y от y1 до y2)
    push si
    push dx          ; y2
    push ax          ; x1
    push bx          ; y1
    push ax          ; x1
    call line_brezenhem

    ; Правая сторона (x = x2, y от y1 до y2)
    push si
    push dx          ; y2
    push cx          ; x2
    push bx          ; y1
    push cx          ; x2
    call line_brezenhem

    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    pop  bp
    ret  10          ; 5 параметров * 2 = 10 байт
DrawRectangle endp


; Заполняет прямоугольник цветом (x1,y1,x2,y2,color)
fill_rect proc
    push bp
    mov  bp, sp
    push ax bx cx dx si di

    mov  ax, [bp+4]   ; x1
    mov  bx, [bp+6]   ; y1
    mov  cx, [bp+8]   ; x2
    mov  dx, [bp+10]  ; y2
    mov  si, [bp+12]  ; color

    ; упорядочиваем координаты
    cmp  ax, cx
    jle  x_ok
    xchg ax, cx
x_ok:
    cmp  bx, dx
    jle y_ok
    xchg bx, dx
y_ok:
    mov  di, bx        ; текущий y
y_loop:
    cmp  di, dx
    jg   done_fill
    push si
    push di            ; y1 = y2 = di
    push cx
    push di
    push ax
    call line_brezenhem   ; рисуем линию от (ax, di) до (cx, di)
    inc  di
    jmp  y_loop
done_fill:
    pop  di si dx cx bx ax
    pop  bp
    ret  10
fill_rect endp





fill_circle proc
    ; ---- Пролог: создаём стековый кадр ----
    push bp                 ; сохраняем старое bp
    mov  bp, sp             ; bp теперь указывает на вершину стека
    sub  sp, 4              ; выделяем 4 байта под локальные переменные:
                            ; [bp-2] = radius (сохраним)
                            ; [bp-4] = color  (сохраним)
    ; ---- Сохраняем регистры, которые будем менять ----
    push ax                 ; сохраняем ax
    push bx                 ; сохраняем bx
    push cx                 ; сохраняем cx
    push dx                 ; сохраняем dx
    push si                 ; сохраняем si
    push di                 ; сохраняем di

    ; ---- Загружаем параметры из стека в регистры ----
    mov  si, [bp+4]         ; si = centerX
    mov  di, [bp+6]         ; di = centerY
    mov  ax, [bp+8]         ; ax = radius
    mov  [bp-2], ax         ; сохраняем radius в локальную переменную
    mov  ax, [bp+10]        ; ax = color
    mov  [bp-4], ax         ; сохраняем color в локальную переменную

    ; ---- Инициализация переменных алгоритма Брезенхема ----
    mov  cx, 0              ; cx = x = 0 (текущий x, растёт)
    mov  dx, [bp-2]         ; dx = y = radius (текущий y, убывает)
    ; decision parameter: d = 2 - 2*radius
    ; Используем bx для хранения d (decision parameter)
    mov  bx, 2              ; bx = 2
    sub  bx, dx             ; bx = 2 - radius
    sub  bx, dx             ; bx = 2 - 2*radius

    ; ---- Рисуем центральную горизонтальную линию (y = centerY) ----
    ; Это самая широкая линия: от centerX - radius до centerX + radius




    push [bp-4]             ; color (word)
    push di                 ; y2 = centerY
    mov  ax, si
    add  ax, [bp-2]         ; ax = centerX + radius
    push ax                 ; x2
    push di                 ; y1 = centerY
    mov  ax, si
    sub  ax, [bp-2]         ; ax = centerX - radius
    push ax                 ; x1
    call line_brezenhem     ; рисуем горизонтальную линию

    ; ---- Основной цикл: пока x <= y ----
circle_loop:
    cmp  cx, dx             ; сравниваем x и y
    jle  circle_continue       ; если x > y, выходим из цикла
    jmp near ptr circle_exit
circle_continue:
    ; ----- 1. Линия: y = centerY + dx (нижняя половина, уровень y) -----
    push [bp-4]             ; color
    mov  ax, di
    add  ax, dx             ; ax = centerY + y
    push ax                 ; y2 = centerY + y
    mov  ax, si
    add  ax, cx             ; ax = centerX + x
    push ax                 ; x2 = centerX + x
    mov  ax, di
    add  ax, dx             ; ax = centerY + y
    push ax                 ; ; y1 = centerY + y (одинаковые, линия горизонтальная)
    mov  ax, si
    sub  ax, cx             ; ax = centerX - x
    push ax                 ; x1
    call line_brezenhem

    ; ----- 2. Линия: y = centerY - dx (верхняя половина, уровень -y) -----
    push [bp-4]             ; color
    mov  ax, di
    sub  ax, dx             ; ax = centerY - y
    push ax                 ; y2
    mov  ax, si
    add  ax, cx             ; x2 = centerX + x
    push ax
     mov  ax, di
    sub  ax, dx             ; ax = centerY - y
    push ax                 ; y1
    mov  ax, si
    sub  ax, cx             ; x1 = centerX - x
    push ax
    call line_brezenhem

    ; ----- 3. Линия: y = centerY + cx (нижняя половина, уровень x) -----
    push [bp-4]             ; color
    mov  ax, di
    add  ax, cx             ; ax = centerY + x
    push ax                 ; y2
    mov  ax, si
    add  ax, dx             ; x2 = centerX + y
    push ax
    mov  ax, di
    add  ax, cx             ; ax = centerY + x
    push ax                 ; y1
    mov  ax, si
    sub  ax, dx             ; x1 = centerX - y
    push ax
    call line_brezenhem

    ; ----- 4. Линия: y = centerY - cx (верхняя половина, уровень -x) -----
    push [bp-4]             ; color
    mov  ax, di
    sub  ax, cx             ; ax = centerY - x
    push ax                 ; y2
    mov  ax, si
    add  ax, dx             ; x2 = centerX + y
    push ax
    mov  ax, di
    sub  ax, cx             ; ax = centerY - x
    push ax                 ; y1
    mov  ax, si
    sub  ax, dx             ; x1 = centerX - y
    push ax
    call line_brezenhem

    ; ---- Обновление переменных x, y и d по алгоритму Брезенхема ----
    cmp  bx, 0              ; проверяем d (decision parameter)
    jle  skip_dec_y         ; если d <= 0, не уменьшаем y
    ; иначе d > 0 -> нужно уменьшить y
    dec  dx                 ; y = y - 1
    ; обновляем d: d = d + 2*(dx - 1) + 1? По формулам Брезенхема:
    ; при d > 0: d = d + 2*(x - y) + 5? Нет, стандартно:
    ; если d > 0: y--, d = d + 2*(x - y) + 5
    ; но проще использовать классический код (проверенный).
    ; Пересчитываем bx: добавляем 2*(x - y) + 5
    mov  ax, cx             ; ax = x
    sub  ax, dx             ; ax = x - y
    shl  ax, 1              ; ax = 2*(x - y)
    add  ax, 5              ; ax = 2*(x - y) + 5
    add  bx, ax             ; bx = bx + 2*(x - y) + 5
    jmp  update_x
skip_dec_y:
    ; при d <= 0: y остаётся, d = d + 2*x + 3
    mov  ax, cx             ; ax = x
    shl  ax, 1              ; ax = 2*x
    add  ax, 3              ; ax = 2*x + 3
    add  bx, ax             ; bx = bx + 2*x + 3
update_x:
    inc  cx                 ; x = x + 1
    jmp  circle_loop        ; повторить цикл

circle_exit:
    ; ---- Эпилог: восстановление регистров и выход ----
    pop  di                 ; восстанавливаем di
    pop  si                 ; восстанавливаем si
    pop  dx                 ; восстанавливаем dx
    pop  cx                 ; восстанавливаем cx
    pop  bx                 ; восстанавливаем bx
    pop  ax                 ; восстанавливаем ax
    mov  sp, bp             ; освобождаем локальные переменные
    pop  bp                 ; восстанавливаем bp
    ret  8                  ; возврат и очистка 4 параметров (8 байт)
fill_circle endp



DrawSwissFlag proc 
    push COL_RED
    push Flags_Y2
    push Flags_X2
    push Flags_Y1
    push Flags_X1
    call DrawRectangle
    push COL_RED
    push Flags_Y2
    push Flags_X2
    push Flags_Y1
    push Flags_X1
    call fill_rect

    push COL_WHITE
    push Vert_CROSS_Y2
    push Vert_CROSS_X2
    push Vert_CROSS_Y1
    push Vert_CROSS_X1
    call DrawRectangle
    push COL_WHITE
    push Vert_CROSS_Y2
    push Vert_CROSS_X2
    push Vert_CROSS_Y1
    push Vert_CROSS_X1
    call fill_rect


    push COL_WHITE
    push Horiz_CROSS_Y2
    push Horiz_CROSS_X2
    push Horiz_CROSS_Y1
    push Horiz_CROSS_X1
    call DrawRectangle
    push COL_WHITE
    push Horiz_CROSS_Y2
    push Horiz_CROSS_X2
    push Horiz_CROSS_Y1
    push Horiz_CROSS_X1
    call fill_rect
    ret
DrawSwissFlag endp




Print_Squre proc 

    push ax
    push bx 
    push cx

    ; ---- Вычисление площади круга (R=90) ----
    ; S = π * R^2, π ≈ 3.14 -> 314/100
    mov  ax, CIRCLE_R
    imul ax          ; ax = 90*90 = 8100
    mov  bx, 314
    imul bx              ; dx:ax = 8100 * 314 = 2 543 400
    mov  cx, 100
    div  cx              ; ax = 2 543 400 / 100 = 25 434
    mov  area_circle, ax

    ; ---- Вычисление площади прямоугольника ----
    mov  ax, RECT_X2
    sub  ax, RECT_X1     ; ширина = 380 - 250 = 130
    mov  bx, RECT_Y2
    sub  bx, RECT_Y1     ; высота = 330 - 255 = 75
    imul bx              ; ax = 130 * 75 = 9 750
    mov  area_rect, ax

    ; ---- Вывод площадей на экран ----
    call PrintArea_Circle
    call PrintArea_Rect

pop cx
pop bx
pop ax

ret
Print_Squre endp





; ВЫВОД ТЕКСТА 
; Преобразует AX в строку, записывает в num_buf и возвращает в SI
NumToStr PROC
    push ax
    push bx
    push cx
    push dx
    push di

        ; очищаем весь буфер нулями
    push di
    mov di, offset num_buf
    mov cx, 15
    xor al, al
    rep stosb
    pop di
    ; теперь записываем цифры с конца
    mov di, offset num_buf + 10   ; последний байт буфера
    mov byte ptr  di , 0
    dec di
    mov bx, 10
nt_loop:
    xor dx, dx
    div bx
    add dl, '0'
    mov [di], dl
    dec di
    cmp ax, 0
    jne nt_loop
    inc di
    mov si, di


    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
NumToStr ENDP


PrintStrAt PROC
    push ax
    push bx
    push cx
    push dx
    push si
    mov  txt_col , bl
    mov  txt_row , bh
    mov  txt_attr , al
    ; Установить курсор
    mov ah, 02h
    mov bh, 0
    mov dh,  txt_row 
    mov dl,  txt_col 
    int 10h
ps_loop:
    mov al, [si]
    cmp al, 0
    je ps_done
    mov ah, 09h
    mov bh, 0
    mov bl,  txt_attr 
    mov cx, 1
    int 10h
    inc si
    inc byte ptr  txt_col 
    mov ah, 02h
    mov bh, 0
    mov dh,  txt_row 
    mov dl,  txt_col 
    int 10h
    jmp ps_loop
ps_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PrintStrAt ENDP


PrintNumber PROC
    push si
    push ax
    push bx
    push cx
    push dx
    mov  pn_col , bl
    mov  pn_row , bh
    mov  pn_attr , al
    mov ax,  pn_num            
    call NumToStr
    mov bl,  pn_col 
    mov bh,  pn_row 
    mov al,  pn_attr 
    call PrintStrAt
    pop dx
    pop cx
    pop bx
    pop ax
    pop si
    ret
PrintNumber ENDP

PrintArea_Circle PROC
    push si
    mov si, offset str_sc
    mov bl, 34 ;Y
    mov bh, 19 ;X
    mov al, COL_WHITE
    call PrintStrAt
    mov ax,  area_circle        ; ax = площадь круга
    mov  pn_num , ax           
    mov bl, 40
    mov bh, 19
    mov al, COL_WHITE
    call PrintNumber
    pop si
    ret
PrintArea_Circle ENDP

PrintArea_Rect PROC
    push si
    mov si, offset str_sr
    mov bl, 34
    mov bh, 18
    mov al, COL_WHITE
    call PrintStrAt
    mov ax,  area_rect          ; ax = площадь прямоугольника
    mov  pn_num , ax            
    mov bl, 40
    mov bh, 18
    mov al, COL_WHITE
    call PrintNumber
    pop si
    ret
PrintArea_Rect ENDP



start:
	mov ax, @data
	mov ds, ax
	mov es, ax

	
	
	;mov bx, 107h
	mov ax, 12h
	int 10h    ;Включение видеорежима VGA


    mov radius, CIRCLE_R    ;Радиус нашего круга.
	mov x0, CIRCLE_X    ;Номер строки, в котором будет находится центр круга
	mov y0, CIRCLE_Y    ;Номер столбца, в котором будет находится центр круга
	call DrawCircle
    push COL_PINK
    push CIRCLE_R        ; radius
    push CIRCLE_Y       ; y0
    push CIRCLE_X       ; x0
    call fill_circle


    push COL_GREEN
    push RECT_Y2
    push RECT_X2
    push RECT_Y1
    push RECT_X1
    call DrawRectangle
    push COL_GREEN
    push RECT_Y2
    push RECT_X2
    push RECT_Y1
    push RECT_X1
    call fill_rect


	;вывод площадей фигур на экран
    call Print_Squre

    ; Ожидание клавиши и очистка экрана
    ;mov ah, 00h
    ;int 16h
    ;call ClearScreen
    ;рисуем флаг 
    call DrawSwissFlag


	; Ожидание клавиши
    mov ah, 00h
    int 16h
    call ClearScreen



exit:
    mov ah, 00h
    mov al, 03h
    int 10h
    mov ah, 4Ch
    int 21h
end	start