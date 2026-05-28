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
    int 10h

main:
    ; Рисуем четыре стороны прямоугольника
    mov al, byte ptr white ;цвет белый

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

    ;рисуем фигуры внутри прямоугольника
    mov al, byte ptr blue ;цвет синий

    mov cx, 145  ; X point X + Xr*5/11!
    mov dx, y1 ; Y poin
    mov si, y2 ;end Y
    call draw_vertical

   
    mov cx, 195  ; X point X + Xr*5/11!
    mov dx, y1  ; Y poin
    mov si, y2 ;end Y
    call draw_vertical
    
    mov cx, x1 ;X point
    mov dx, 115  ; Y point fix  Y +Yr*1/4!
    mov si, x2  ; end X
    call draw_horizontal

    mov cx, x1 ;X point
    mov dx, 165  ; Y point fix  Y +Yr*1/4!
    mov si, x2  ; end X
    call draw_horizontal
;заливаем вертикальный прямоугольник

    mov cx,145
    mov di,195
    mov dx,y1
    mov si,y2
    call fill_rectangle

;заливаем горизонтальный прямоугольник
    mov cx,x1
    mov di,x2
    mov dx,115
    mov si,165
    call fill_rectangle


    


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


end start