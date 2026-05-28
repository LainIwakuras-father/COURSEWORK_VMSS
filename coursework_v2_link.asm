.8086 ; Набор команд для процессора не ниже 8086
.MODEL small ; Модель памяти в этой модели упрощеное работа с передачей аргументов процедуре через стек с помощью push  И  pop
.stack 100h ; Размер стека 256 байт
.data ; Начало сегмента данных
    ;цвета
    blue dw 01h
    white  dw 0Fh
    ;координаты флага 
    x1 dw 60
x2 dw 300   ; было 380 – выходит за экран (макс 319)
y1 dw 40
y2 dw 180   ; было 240 – выходит за экран (макс 199)
.code ; Начало сегмента кода
;рисование линии по алгоритму Брезенхейма\
line_brezenhem proc uses ax bx cx dx si di, START_X:word, START_Y:word, END_X:word, END_Y:word, COLOR:word ; 5 слов  = 10 байт 
local DIAGONAL_Y_INCREMENT:word
local DIAGONAL_X_INCREMENT:word
local SHORT_DISTANCE:word
local STRAIGHT_X_INCREMENT:word
local STRAIGHT_Y_INCREMENT:word
local STRAIGHT_COUNT:word
local DIAGONAL_COUNT:word
        mov ax,START_X          ;если координаты начала и конца совпадают
        cmp ax,END_X
        jnz ris
        mov ax,START_Y          ;если нет - рисовать линию
        cmp ax,END_Y
        jnz ris
        mov dx,ax
        mov cx,START_X
        MOV  AL, byte ptr COLOR
        mov bh,0
        mov ah,0ch
        int 10h              ;вывести одну  точку
 
        jmp LINE_FINISHED
ris:
;---установка начальных инкрементов для каждой позиции точки
               MOV  CX,1       ;инкремент для оси x
               MOV  DX,1       ;инкремент для оси y
;---вычисление вертикальной дистанции
               MOV  DI,END_Y   ;вычитаем координату начальной
               SUB  DI,START_Y ;точки из координаты конечной
               JGE  KEEP_Y     ;вперед если наклон < 0
               NEG  DX         ;иначе инкремент равен -1
               NEG  DI         ;а дистанция должна быть > 0
KEEP_Y:        MOV  DIAGONAL_Y_INCREMENT,DX
;---вычисление горизонтальной дистанции
               MOV  SI,END_X   ;вычитаем координату начальной
               SUB  SI,START_X ;точки из координаты конечной
               JGE  KEEP_X     ;вперед если наклон < 0
               NEG  CX         ;иначе инкремент равен -1
               NEG  SI         ;а дистанция должна быть > 0
KEEP_X:        MOV  DIAGONAL_X_INCREMENT,CX
;---определяем горизонтальны или вертикальны прямые сегменты
               CMP  SI,DI      ;горизонтальные длиннее?
               JGE  HORZ_SEG   ;если да, то вперед
               MOV  CX,0       ;иначе для прямых x не меняется
               XCHG SI,DI      ;помещаем большее в CX
               JMP  SAVE_VALUES;сохраняем значения
HORZ_SEG:      MOV  DX,0       ;теперь для прямых не меняется y
SAVE_VALUES:   MOV  SHORT_DISTANCE,DI  ;меньшее расстояние
               MOV  STRAIGHT_X_INCREMENT,CX  ;один из них 0,
               MOV  STRAIGHT_Y_INCREMENT,DX  ;а другой - 1.
;---вычисляем выравнивающий фактор
               MOV  AX,SHORT_DISTANCE  ;меньшее расстояние в AX
               SHL  AX,1       ;удваиваем его
               MOV  STRAIGHT_COUNT,AX  ;запоминаем его
               SUB  AX,SI      ;2*меньшее - большее
               MOV  BX,AX      ;запоминаем как счетчик цикла
               SUB  AX,SI      ;2*меньшее - 2*большее
               MOV  DIAGONAL_COUNT,AX  ;запоминаем
;---подготовка к выводу линии
               MOV  CX,START_X ;начальная координата x
               MOV  DX,START_Y ;начальная координата y
               INC  SI         ;прибавляем 1 для конца
               MOV  AL, byte ptr COLOR   ;берем код цвета
;---теперь выводим линию
MAINLOOP:      DEC  SI         ;счетчик для большего расстояния
               JZ   LINE_FINISHED  ;выход после последней точки
               push bx
               mov bh,0
               mov ah,0ch
               int 10h
               pop bx
;               CALL put_pixel



SKIP:          CMP  BX,0       ;если BX < 0, то прямой сегмент
               JGE  DIAGONAL_LINE  ;иначе диагональный сегмент
;---выводим прямые сегменты
               ADD  CX,STRAIGHT_X_INCREMENT  ;определяем инкре-
               ADD  DX,STRAIGHT_Y_INCREMENT  ;менты по осям
               ADD  BX,STRAIGHT_COUNT  ;фактор выравнивания
               JMP  SHORT MAINLOOP  ;на следующую точку
;---выводим диагональные сегменты
DIAGONAL_LINE: ADD  CX,DIAGONAL_X_INCREMENT  ;определяем инкре-
               ADD  DX,DIAGONAL_Y_INCREMENT  ;менты по осям
               ADD  BX,DIAGONAL_COUNT  ;фактор выравнивания
               JMP  SHORT MAINLOOP  ;на следующую точку
LINE_FINISHED:
 
ret
line_brezenhem  endp

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

start:
    mov dx,@stack ; через регистр dx в стековый регистр ss засылается
    mov ss,dx ; начальный адрес сегмента стека
    mov dx,@data
    mov ds,dx

    ;сохранение режима терминала
    mov ah, 0Fh
    int 10h
    push ax

    mov ax, 12h
    int 10h

; Рисуем четыре стороны прямоугольника
    ; вызов процедуры line – передаём параметры через стек (ПЕРЕДАЕМ В ОБРАТНОМ ПОРЯДКЕ ОБЪЯВЛЕНИЯ АРГУМЕНТОВ начиная с color)
    push blue ; в модели .small в push pop передают только 2 байтовые слова меньше нельзя
    push y2
    push x2
    push y1
    push x1
    call line_brezenhem
    ;востанавливаем sp
     add sp,10

    ; Верхняя сторона (y1 постоянна, x от x1 до x2)
    push white
    push y1
    push x2
    push y1
    push x1
    call line_brezenhem
    ;востанавливаем sp
     add sp,10


; Нижняя сторона (y2 постоянна)
    push white
    push y2
    push x2
    push y2
    push x1
    call line_brezenhem
    ;востанавливаем sp
     add sp,10

; Левая сторона (x1 постоянна)
    push white
    push y2
    push x1
    push y1
    push x1
    call line_brezenhem
    ;востанавливаем sp
   add sp,10


; Правая сторона (x2 постоянна)
    push white
    push y2
    push x2
    push y1
    push x2
    call line_brezenhem
    ;востанавливаем sp
    add sp,10


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

end start