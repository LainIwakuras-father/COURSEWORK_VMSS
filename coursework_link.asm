.model tiny
.code
org 100h

start:
    ;Данные
    ;координаты флага 
    ;координаты треугольника




    ;сохранение режима терминала
    mov ah, 0Fh
    int 10h
    push ax

    ; Установка видеорежима 107h = 1280x1024, 256 цветов
    mov bx, 107h
    mov ax, 4F02h
    int 10h



main:

    ; Рисуем четыре стороны прямоугольника
    mov cx, x1
    mov dx, y1
    mov si, x2
    call draw_horizontal          ; верхняя сторона

    mov cx, x1
    mov dx, y2
    mov si, x2
    call draw_horizontal          ; нижняя сторона

    mov cx, x1
    mov dx, y1
    mov si, y2
    call draw_vertical            ; левая сторона

    mov cx, x2
    mov dx, y1
    mov si, y2
    call draw_vertical            ; правая сторона


    mov cx,x1
    mov di,x2
    mov dx,y1
    mov si,y2
    call fill_rectangle

;заливаем вертикальный прямоугольник
    mov cx,145
    mov di,195
    mov dx,y1
    mov si,y2
    call fill_rectangle_blue

;заливаем горизонтальный прямоугольник
    mov cx,x1
    mov di,x2
    mov dx,115
    mov si,165
    call fill_rectangle_blue


    ;рисуем фигуры внутри прямоугольника
    ;x1 dw 60
;x2 dw 380
;y1 dw 40
;y2 dw 240

    mov cx, 145  ; X point X + Xr*5/11!
    mov dx, y1 ; Y poin
    mov si, y2 ;end Y
    call draw_vertical_blue

    mov cx, 195  ; X point X + Xr*5/11!
    mov dx, y1  ; Y poin
    mov si, y2 ;end Y
    call draw_vertical_blue
    
    mov cx, x1 ;X point
    mov dx, 115  ; Y point fix  Y +Yr*1/4!
    mov si, x2  ; end X
    call draw_horizontal_blue

     mov cx, x1 ;X point
    mov dx, 165  ; Y point fix  Y +Yr*1/4!
    mov si, x2  ; end X
    call draw_horizontal_blue


    ; Ожидание клавиши
    mov ah, 00h
    int 16h

exit:
    pop ax
    mov ah, 00h
    mov al, 03h
    int 10h
    mov ah, 4Ch
    int 21h

; ===== Универсальная горизонтальная линия =====

draw_horizontal proc
draw_h_loop:
    call put_pixel_white
    inc cx
    cmp cx, si
    jbe draw_h_loop
    ret
draw_horizontal endp

draw_vertical proc
draw_v_loop:
    call put_pixel_white
    inc dx
    cmp dx, si
    jbe draw_v_loop
    ret
draw_vertical endp


draw_horizontal_blue proc
draw_h_b_loop:
    call put_pixel_blue
    inc cx
    cmp cx, si
    jbe draw_h_b_loop
    ret
draw_horizontal_blue endp

draw_vertical_blue proc
draw_v_b_loop:
    call put_pixel_blue
    inc dx
    cmp dx, si
    jbe draw_v_b_loop
    ret
draw_vertical_blue endp



fill_rectangle proc
    fill_y:
        push cx
    fill_x:
        call put_pixel_white
        inc cx
        cmp cx, di
        jle fill_x
        pop cx
        inc dx
        cmp dx, si
        jle fill_y
        ret
fill_rectangle endp

fill_rectangle_blue proc
    fill_y_b:
        push cx
    fill_x_b:
        call put_pixel_blue
        inc cx
        cmp cx, di
        jle fill_x_b
        pop cx
        inc dx
        cmp dx, si
        jle fill_y_b
        ret
fill_rectangle_blue endp

; ===== Вывод точки (через BIOS) =====
put_pixel_white proc
    mov ah, 0Ch
    mov bh, 0
    mov al, 0Fh            ; белый цвет 15
    int 10h
    ret
put_pixel_white endp

put_pixel_blue proc
    mov ah, 0Ch
    mov bh, 0
    mov al, 01h            ; белый цвет 15
    int 10h
    ret
put_pixel_blue endp


; ===== Константы прямоугольника =====
x1 dw 60
x2 dw 380
y1 dw 40
y2 dw 240



;Алгоритм Брезенхема реализация
line_brezenhem proc
;если координаты начала и конца совпадают
    mov ax, START_X     ; обозначения координат для (x1,y1) и (x2,y2)
    cmp ax, END_X  
    jnz short DRAW
    mov ax, START_Y
    cmp ax, END_Y
    jnz short DRAW

    mov dx, ; y1
    mov cx, ; x1
    call put_pixel_blue ;вызов функции вывода одной точки
    jmp LINE_FINISHED

    DRAW:
    ;установка нач-ч инкрементов для каждой точки
        mov cx, 1 ;инкремент для оси х 
        mov dx, 1 ;инкремент для оси y это SignA
        ;вычисление вертикальной дистанции
        mov di, END_Y ; di это A = Y2 - Y1 вычитаем координату начальной  точки из координаты конечно
        sub di, START_Y
        jge KEEP_Y; вперед если наклон < 0
        neg dx ; иначе инкремент SignA = -1 
        neg di ; в дистанции должна быть  >0

    KEEP_X:
        mov DIAGONAL_Y_INCREMENT, dx

        ;вычисление горизонтальной дистанции
        mov si, END_X ; di это B = Y2 - Y1 вычитаем координату начальной  точки из координаты конечно
        sub si, START_X
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
        mov SHORT_DISTANSE, di ; меньшее растояние 
        mov STRAIGHT_X_INCREMENT, cx ; один из них 0
        mov STRAIGHT_Y_INCREMENT, dx ; а в другой -1
        mov ax, SHORT_DISTANSE ;меньшее растояние в ax
        shl ax,1 ;удваиваем его shl - инструкция  выполняющая логический сдвиг влево содержимого регистра ax на 1 бит. что посути умножение на 2 как C

        mov STRAIGHT_COUNT,ax
        sub ax,si ;2* меньшее - большее
        mov bx, ax ;запоминаем как счетчик цикла 
        sub ax,si ;2*меньшее - 2*большее
        mov DIAGONAL_COUNT, ax ; запоминаем

        ;подготовка к выводу линии
        mov cx, START_X; начальная координата х
        mov dx, START_Y; началаьная координат y

        inc si
        mov al, byte ptr COLOR ;для вывода определенного цвета
        
        ;теперь выводим линию
    MAINLOOP:
        dec si; счетчик для большего расстояния
        jz LINE_FINISHED; вывод последней точки
        push bx
        mov bh 
        mov ax, 0Ch
        int 10h

        pop bx

        call put_pixel_blue
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
        add cx, STRAIGHT_X_INCREMENT; определяем инкременты по осям
        add dx, STRAIGHT_Y_INCREMENT; 
        add bx, DIAGONAL_COUNT;  фактор выравнивания
        
        jmp short MAINLOOP; на след точку
    
    LINE_FINISHED:
        ret
line_brezenhem endp


end start