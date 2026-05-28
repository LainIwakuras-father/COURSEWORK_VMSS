.model tiny
.code
org 100h

start:
    
    ;сохранение режима терминала
    mov ah, 0Fh
    int 10h
    push ax

    ; Установка видеорежима 107h = 1280x1024, 256 цветов
    mov bx, 107h
    mov ax, 4F02h
    ;mov ax, 13h
    int 10h

main:
    ; Рисуем четыре стороны прямоугольника
     

    ; Пример вызова горизонтальной линии 
    mov ax, x1
    mov word ptr [START_X], ax
    mov ax, y1
    mov word ptr [START_Y], ax
    mov ax, x2
    mov word ptr [END_X], ax
    mov ax, y2
    mov word ptr [END_Y], ax
    mov al, blue
    mov byte ptr [COLOR], al
    call line_brezenhem



    ; Верхняя сторона (y1 постоянна, x от x1 до x2)
mov ax, x1
mov START_X, ax
mov ax, y1
mov START_Y, ax
mov ax, x2
mov END_X, ax
mov ax, y1
mov END_Y, ax
mov al, white
mov COLOR, al
call line_brezenhem

; Нижняя сторона (y2 постоянна)
mov ax, x1
mov START_X, ax
mov ax, y2
mov START_Y, ax
mov ax, x2
mov END_X, ax
mov ax, y2
mov END_Y, ax
mov al, white
mov COLOR, al
call line_brezenhem

; Левая сторона (x1 постоянна)
mov ax, x1
mov START_X, ax
mov ax, y1
mov START_Y, ax
mov ax, x1
mov END_X, ax
mov ax, y2
mov END_Y, ax
mov al, white
mov COLOR, al
call line_brezenhem

; Правая сторона (x2 постоянна)
mov ax, x2
mov START_X, ax
mov ax, y1
mov START_Y, ax
mov ax, x2
mov END_X, ax
mov ax, y2
mov END_Y, ax
mov al, white
mov COLOR, al
call line_brezenhem

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
    call put_pixel
    inc cx
    cmp cx, si
    jbe draw_h_loop
    ret
draw_horizontal endp

draw_vertical proc
draw_v_loop:
    call put_pixel
    inc dx
    cmp dx, si
    jbe draw_v_loop
    ret
draw_vertical endp


fill_rectangle proc ;это заливки
    fill_y:
        push cx
    fill_x:
        call put_pixel
        inc cx
        cmp cx, di
        jle fill_x
        pop cx
        inc dx
        cmp dx, si
        jle fill_y
        ret
fill_rectangle endp



; ===== Вывод точки (через BIOS) =====
;mov al, byte ptr white or blue
put_pixel proc; 1 blue   белый цвет 15
    mov ah, 0Ch
    mov bh, 0  
    int 10h
    ret
put_pixel endp




;Алгоритм Брезенхема реализация
line_brezenhem proc
;если координаты начала и конца совпадают
    mov ax, START_X     ; обозначения координат для (x1,y1) и (x2,y2)
    cmp ax, END_X  
    jnz short DRAW
    mov ax, START_Y
    cmp ax, END_Y
    jnz short DRAW

    mov dx,ax ; y1
    mov cx,START_X ; x1
    mov al, COLOR
    call put_pixel ;вызов функции вывода одной точки
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


    KEEP_Y:
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

       
        ;теперь выводим линию
    MAINLOOP:
        dec si; счетчик для большего расстояния
        jz LINE_FINISHED; вывод последней точки
        mov al, COLOR
        call put_pixel
        
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
        ret
line_brezenhem endp



;Данные
    
    
    blue db 01h
    white  db 0Fh
    ;координаты флага 
    x1 dw 60
    x2 dw 380
    y1 dw 40
    y2 dw 240
    ;координаты маленьких прямоуголников для креста внутри флага
    ;координаты треугольника


    ;аргументы функции
    COLOR   db 0
    START_X dw 0
    START_Y dw 0
    END_X   dw 0
    END_Y   dw 0

    ;локальные переменные функции
    DIAGONAL_Y_INCREMENT dw 0
    DIAGONAL_X_INCREMENT dw 0
    SHORT_DISTANSE dw 0
    STRAIGHT_X_INCREMENT dw 0
    STRAIGHT_Y_INCREMENT dw 0
    STRAIGHT_COUNT dw 0
    DIAGONAL_COUNT dw 0

end start