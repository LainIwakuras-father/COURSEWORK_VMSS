.model tiny
.386
.code
org 100h

start:
    jmp main

; ==================== ДАННЫЕ ====================
menu_msg         db '1 - Create and save figure',13,10
                 db '2 - Load figure from file',13,10
                 db 'Choice: $'
fig_msg          db 13,10,'Choose figure:',13,10
                 db '1 - Square',13,10
                 db '2 - Rhombus',13,10
                 db '3 - Triangle',13,10
                 db '4 - Star',13,10
                 db '5 - Trapezoid',13,10
                 db 'Choice: $'
filename_msg     db 13,10,'Enter filename (e.g., PIC.RIS): $'
click_msg        db 13,10,'Click inside the figure to save. Press any key when ready...$'
not_inside_msg   db 7,'Click was NOT on the figure! Try again.',13,10,'$'
err_msg          db 13,10,'Error!$'
ok_msg           db 13,10,'Saved successfully!$'
anykey_msg       db 13,10,'Press any key to return to DOS...$'

filename         db 20 dup(0)
ris_header       dw 320, 200
buf              db 128 dup(?)

figure_type      db 0
color_white      equ 15

; параметры квадрата
sq_left   equ 110
sq_top    equ 50
sq_right  equ 210
sq_bottom equ 150

; параметры ромба
rh_cx     dw 160
rh_cy     dw 100
rh_hw     dw 70
rh_hh     dw 60

; переменные алгоритма Брезенхема
bren_x0     dw 0
bren_y0     dw 0
bren_x1     dw 0
bren_y1     dw 0
bren_dx     dw 0
bren_dy     dw 0
bren_sx     dw 0
bren_sy     dw 0
bren_steep  dw 0
bren_err    dw 0

; вершины звезды
star_x   dw 160, 210, 310, 210, 260, 160, 60, 110, 10, 110
star_y   dw 20,  80,  100, 140, 200, 160, 200,140,100,80
star_n   equ 10

; переменные для hit_star
pt_x     dw 0
pt_y     dw 0
edge_x1  dw 0
edge_y1  dw 0
edge_x2  dw 0
edge_y2  dw 0
f1       db 0
f2       db 0
dy_edge  dw 0
dy1_edge dw 0
dx_edge  dw 0
res_star db 0

; ==================== ПОДПРОГРАММЫ ====================
print proc
    push ax
    mov ah, 9
    int 21h
    pop ax
    ret
print endp

input_string proc
    push ax
    mov ah, 0Ah
    int 21h
    pop ax
    ret
input_string endp

set_video_mode proc
    mov ah, 0
    int 10h
    ret
set_video_mode endp

init_mouse proc
    xor ax, ax
    int 33h
    mov ax, 4
    mov cx, 320
    mov dx, 100
    int 33h
    ret
init_mouse endp

show_mouse proc
    mov ax, 1
    int 33h
    ret
show_mouse endp

hide_mouse proc
    mov ax, 2
    int 33h
    ret
hide_mouse endp

; ожидание левого клика с гарантированным завершением после отпускания
wait_left_click proc
    push ax
    push bx
    ; сначала ждём нажатия
wait_lc_press:
    mov ax, 3
    int 33h
    test bx, 1
    jz wait_lc_press
    ; теперь ждём отпускания, чтобы избежать мгновенного повторного срабатывания
wait_lc_release:
    mov ax, 3
    int 33h
    test bx, 1
    jnz wait_lc_release
    shr cx, 1              ; X 0..639 -> 0..319
    pop bx
    pop ax
    ret
wait_left_click endp

; больше не используется, оставлена для совместимости
wait_left_release proc
    push ax
    push bx
wlr_loop:
    mov ax, 3
    int 33h
    test bx, 1
    jnz wlr_loop
    pop bx
    pop ax
    ret
wait_left_release endp

putpixel proc
    pusha
    push 0A000h
    pop es
    mov di, cx
    imul di, di, 320
    add di, bx
    mov es:[di], al
    popa
    ret
putpixel endp

horiz_line proc
    pusha
    push 0A000h
    pop es
    mov di, dx
    imul di, di, 320
    add di, bx
    mov cx, cx
    sub cx, bx
    inc cx
    rep stosb
    popa
    ret
horiz_line endp

vert_line proc
    pusha
    push 0A000h
    pop es
    mov di, cx
    imul di, di, 320
    add di, bx
vert_loop:
    mov es:[di], al
    add di, 320
    inc cx
    cmp cx, dx
    jle vert_loop
    popa
    ret
vert_line endp

; ---------- Алгоритм Брезенхема ----------
line_bresenham proc
    pusha
    mov word ptr [bren_x0], ax
    mov word ptr [bren_y0], bx
    mov word ptr [bren_x1], cx
    mov word ptr [bren_y1], dx

    mov ax, word ptr [bren_x1]
    sub ax, word ptr [bren_x0]
    jns bren_dx_abs
    neg ax
bren_dx_abs:
    mov word ptr [bren_dx], ax

    mov ax, word ptr [bren_y1]
    sub ax, word ptr [bren_y0]
    jns bren_dy_abs
    neg ax
bren_dy_abs:
    mov word ptr [bren_dy], ax

    mov word ptr [bren_sx], 1
    mov ax, word ptr [bren_x0]
    cmp ax, word ptr [bren_x1]
    jle bren_sx_ok
    neg word ptr [bren_sx]
bren_sx_ok:
    mov word ptr [bren_sy], 1
    mov ax, word ptr [bren_y0]
    cmp ax, word ptr [bren_y1]
    jle bren_sy_ok
    neg word ptr [bren_sy]
bren_sy_ok:

    mov ax, word ptr [bren_dx]
    cmp ax, word ptr [bren_dy]
    jae bren_shallow

    mov word ptr [bren_steep], 1
    mov ax, word ptr [bren_dx]
    shl ax, 1
    sub ax, word ptr [bren_dy]
    mov word ptr [bren_err], ax

    mov ax, word ptr [bren_x0]
    mov bx, word ptr [bren_y0]
    mov cx, word ptr [bren_dy]
bren_steep_loop:
    pusha
    mov cx, bx
    mov bx, ax
    mov al, 15
    call putpixel
    popa

    cmp word ptr [bren_err], 0
    jl bren_steep_err_lt
    add ax, word ptr [bren_sx]
    mov dx, word ptr [bren_err]
    sub dx, word ptr [bren_dy]
    sub dx, word ptr [bren_dy]
    mov word ptr [bren_err], dx
bren_steep_err_lt:
    add bx, word ptr [bren_sy]
    mov dx, word ptr [bren_err]
    add dx, word ptr [bren_dx]
    add dx, word ptr [bren_dx]
    mov word ptr [bren_err], dx
    dec cx
    jns bren_steep_loop
    jmp bren_done

bren_shallow:
    mov word ptr [bren_steep], 0
    mov ax, word ptr [bren_dy]
    shl ax, 1
    sub ax, word ptr [bren_dx]
    mov word ptr [bren_err], ax

    mov ax, word ptr [bren_x0]
    mov bx, word ptr [bren_y0]
    mov cx, word ptr [bren_dx]
bren_shallow_loop:
    pusha
    mov cx, bx
    mov bx, ax
    mov al, 15
    call putpixel
    popa

    cmp word ptr [bren_err], 0
    jl bren_shallow_err_lt
    add bx, word ptr [bren_sy]
    mov dx, word ptr [bren_err]
    sub dx, word ptr [bren_dx]
    sub dx, word ptr [bren_dx]
    mov word ptr [bren_err], dx
bren_shallow_err_lt:
    add ax, word ptr [bren_sx]
    mov dx, word ptr [bren_err]
    add dx, word ptr [bren_dy]
    add dx, word ptr [bren_dy]
    mov word ptr [bren_err], dx
    dec cx
    jns bren_shallow_loop

bren_done:
    popa
    ret
line_bresenham endp

; ---------- ПРОВЕРКИ ПОПАДАНИЯ ----------
hit_square proc
    cmp cx, sq_left
    jl hs_no
    cmp cx, sq_right
    jg hs_no
    cmp dx, sq_top
    jl hs_no
    cmp dx, sq_bottom
    jg hs_no
    mov al, 1
    ret
hs_no:
    xor al, al
    ret
hit_square endp

hit_rhombus proc
    push cx
    push dx
    mov ax, cx
    sub ax, rh_cx
    jns hr_pos1
    neg ax
hr_pos1:
    mov bx, ax
    mov ax, dx
    sub ax, rh_cy
    jns hr_pos2
    neg ax
hr_pos2:
    imul bx, word ptr rh_hh
    imul ax, word ptr rh_hw
    add ax, bx
    mov cx, word ptr rh_hw
    imul cx, word ptr rh_hh
    cmp ax, cx
    jle hr_yes
    pop dx
    pop cx
    xor al, al
    ret
hr_yes:
    pop dx
    pop cx
    mov al, 1
    ret
hit_rhombus endp

hit_triangle_fast proc
    cmp dx, 30
    jl htr_no
    cmp dx, 140
    jg htr_no
    mov ax, dx
    sub ax, 30
    push ax
    imul ax, ax, 70
    mov bx, 110
    cwd
    idiv bx
    mov si, 160
    sub si, ax
    pop ax
    push si
    imul ax, ax, 70
    cwd
    idiv bx
    add ax, 160
    pop bx
    cmp cx, bx
    jl htr_no
    cmp cx, ax
    jg htr_no
    mov al, 1
    ret
htr_no:
    xor al, al
    ret
hit_triangle_fast endp

; ---------- Попадание в звезду (алгоритм луча) ----------
;
; ИСПРАВЛЕНИЕ двух критических ошибок оригинала:
;
; 1. СЧЁТЧИК ПЕРЕСЕЧЕНИЙ: оригинал использовал регистр AH как счётчик,
;    но AH — это старший байт AX. Каждая инструкция MOV AX,[...] внутри
;    цикла перезаписывала счётчик. Например, star_x[2]=310=0x0136,
;    после загрузки AH=0x01 — счётчик испорчен.
;    ИСПРАВЛЕНИЕ: использовать BP (сохранён PUSHA, не затрагивается MOV AX).
;
; 2. ИНДЕКС ВЕРШИНЫ: оригинал хранил индекс i в BX, но при вычислении
;    пересечения выполнял MOV BX,[dy_edge], разрушая индекс. Следующий
;    INC BX инкрементировал dy_edge вместо i — цикл уходил в невалидную
;    память, провоцируя исключение деления и потерю курсора.
;    ИСПРАВЛЕНИЕ: оборачиваем деление в PUSH BX / POP BX.
;
hit_star proc
    pusha
    mov [pt_x], cx          ; сохраняем координаты клика
    mov [pt_y], dx

    xor bp, bp              ; BP = счётчик пересечений
                            ; (безопасен: MOV AX,... не затрагивает BP)
    mov cx, star_n          ; CX = счётчик рёбер (10)
    xor bx, bx              ; BX = индекс текущей вершины i (начинаем с 0)
    mov si, offset star_x
    mov di, offset star_y

hst_loop:
    ; --- загружаем вершину i ---
    push bx
    shl bx, 1               ; bx *= 2 (смещение в байтах для WORD-массива)
    mov ax, [si+bx]
    mov [edge_x1], ax       ; edge_x1 = star_x[i]
    mov ax, [di+bx]
    mov [edge_y1], ax       ; edge_y1 = star_y[i]
    pop bx                  ; восстанавливаем индекс i

    ; --- загружаем вершину (i+1) mod n ---
    push bx
    inc bx
    cmp bx, star_n
    jb hst_next_ok
    sub bx, star_n          ; перенос: если i+1==n, берём вершину 0
hst_next_ok:
    shl bx, 1
    mov ax, [si+bx]
    mov [edge_x2], ax       ; edge_x2 = star_x[(i+1) mod n]
    mov ax, [di+bx]
    mov [edge_y2], ax       ; edge_y2 = star_y[(i+1) mod n]
    pop bx                  ; восстанавливаем индекс i

    ; --- проверяем условие: (y1 > pt_y) != (y2 > pt_y) ---
    ; Ребро должно пересекать горизонталь, проходящую через точку клика
    mov ax, [edge_y1]
    cmp ax, [pt_y]
    setg [f1]
    mov ax, [edge_y2]
    cmp ax, [pt_y]
    setg [f2]
    mov al, [f1]
    xor al, [f2]
    jz hst_next             ; оба конца по одну сторону — пропускаем

    ; --- dy = y2 - y1 ---
    mov ax, [edge_y2]
    sub ax, [edge_y1]
    mov [dy_edge], ax
    je hst_next             ; горизонтальное ребро — пропускаем

    ; --- dy1 = pt_y - y1 ---
    mov ax, [pt_y]
    sub ax, [edge_y1]
    mov [dy1_edge], ax

    ; --- dx_edge = x2 - x1 ---
    mov ax, [edge_x2]
    sub ax, [edge_x1]
    mov [dx_edge], ax

    ; --- x_intersect = x1 + (dy1 * dx_edge) / dy ---
    ; ВАЖНО: сохраняем BX (индекс i) перед тем как IDIV испортит его!
    push bx                 ; сохраняем индекс вершины
    mov ax, [dy1_edge]
    imul word ptr [dx_edge] ; DX:AX = dy1 * dx_edge
    mov bx, [dy_edge]
    idiv bx                 ; AX = (dy1 * dx_edge) / dy,  DX = остаток
    pop bx                  ; восстанавливаем индекс вершины

    add ax, [edge_x1]       ; AX = x_intersect
    cmp ax, [pt_x]
    jle hst_next            ; пересечение слева или на уровне точки — не считаем
    inc bp                  ; пересечение правее точки — увеличиваем счётчик

hst_next:
    inc bx                  ; следующая вершина
    dec cx
    jnz hst_loop

    ; нечётное число пересечений → точка внутри фигуры
    test bp, 1
    jz hst_outside
    mov al, 1
    jmp hst_done
hst_outside:
    xor al, al
hst_done:
    mov [res_star], al
    popa
    mov al, [res_star]
    ret
hit_star endp

hit_trapezoid proc
    cmp dx, 60
    jl htrp_no
    cmp dx, 140
    jg htrp_no
    mov ax, dx
    sub ax, 60
    push ax
    imul ax, ax, 40
    mov bx, 80
    cwd
    idiv bx
    mov si, 130
    sub si, ax
    pop ax
    push si
    imul ax, ax, 40
    cwd
    idiv bx
    add ax, 190
    pop bx
    cmp cx, bx
    jl htrp_no
    cmp cx, ax
    jg htrp_no
    mov al, 1
    ret
htrp_no:
    xor al, al
    ret
hit_trapezoid endp

; ---------- РИСОВАНИЕ ФИГУР ----------
draw_square proc
    mov al, color_white
    mov bx, sq_left
    mov cx, sq_right
    mov dx, sq_top
    call horiz_line
    mov dx, sq_bottom
    call horiz_line
    mov bx, sq_left
    mov cx, sq_top
    mov dx, sq_bottom
    call vert_line
    mov bx, sq_right
    call vert_line
    ret
draw_square endp

draw_rhombus proc
    mov al, color_white
    mov ax, 160
    mov bx, 40
    mov cx, 230
    mov dx, 100
    call line_bresenham

    mov ax, 230
    mov bx, 100
    mov cx, 160
    mov dx, 160
    call line_bresenham

    mov ax, 160
    mov bx, 160
    mov cx, 90
    mov dx, 100
    call line_bresenham

    mov ax, 90
    mov bx, 100
    mov cx, 160
    mov dx, 40
    call line_bresenham
    ret
draw_rhombus endp

draw_triangle proc
    mov al, color_white
    mov ax, 160
    mov bx, 30
    mov cx, 90
    mov dx, 140
    call line_bresenham

    mov ax, 90
    mov bx, 140
    mov cx, 230
    mov dx, 140
    call line_bresenham

    mov ax, 230
    mov bx, 140
    mov cx, 160
    mov dx, 30
    call line_bresenham
    ret
draw_triangle endp

draw_star_fast proc
    mov al, color_white
    mov ax, 160
    mov bx, 20
    mov cx, 210
    mov dx, 80
    call line_bresenham

    mov ax, 210
    mov bx, 80
    mov cx, 310
    mov dx, 100
    call line_bresenham

    mov ax, 310
    mov bx, 100
    mov cx, 210
    mov dx, 140
    call line_bresenham

    mov ax, 210
    mov bx, 140
    mov cx, 260
    mov dx, 200
    call line_bresenham

    mov ax, 260
    mov bx, 200
    mov cx, 160
    mov dx, 160
    call line_bresenham

    mov ax, 160
    mov bx, 160
    mov cx, 60
    mov dx, 200
    call line_bresenham

    mov ax, 60
    mov bx, 200
    mov cx, 110
    mov dx, 140
    call line_bresenham

    mov ax, 110
    mov bx, 140
    mov cx, 10
    mov dx, 100
    call line_bresenham

    mov ax, 10
    mov bx, 100
    mov cx, 110
    mov dx, 80
    call line_bresenham

    mov ax, 110
    mov bx, 80
    mov cx, 160
    mov dx, 20
    call line_bresenham
    ret
draw_star_fast endp

draw_trapezoid proc
    mov al, color_white
    mov bx, 130
    mov cx, 190
    mov dx, 60
    call horiz_line
    mov bx, 90
    mov cx, 230
    mov dx, 140
    call horiz_line

    mov ax, 130
    mov bx, 60
    mov cx, 90
    mov dx, 140
    call line_bresenham

    mov ax, 190
    mov bx, 60
    mov cx, 230
    mov dx, 140
    call line_bresenham
    ret
draw_trapezoid endp

; ---------- СОХРАНЕНИЕ / ЗАГРУЗКА ----------
save_ris proc
    pusha
    mov ah, 3Ch
    mov cx, 0
    mov dx, offset filename+2
    int 21h
    jc save_err_lbl
    mov bx, ax
    mov ah, 40h
    mov cx, 4
    mov dx, offset ris_header
    int 21h
    mov cx, 64000
    push 0A000h
    pop ds
    xor dx, dx
    mov ah, 40h
    int 21h
    mov ah, 3Eh
    int 21h
    push cs
    pop ds
    jmp save_done_lbl
save_err_lbl:
    mov dx, offset err_msg
    call print
save_done_lbl:
    popa
    ret
save_ris endp

load_ris proc
    pusha
    mov ah, 3Dh
    mov al, 0
    mov dx, offset filename+2
    int 21h
    jc load_err_lbl
    mov bx, ax
    mov ah, 3Fh
    mov cx, 4
    mov dx, offset buf
    int 21h
    mov cx, 64000
    push 0A000h
    pop ds
    xor dx, dx
    mov ah, 3Fh
    int 21h
    mov ah, 3Eh
    int 21h
    push cs
    pop ds
    jmp load_done_lbl
load_err_lbl:
    mov dx, offset err_msg
    call print
load_done_lbl:
    popa
    ret
load_ris endp

; ================ ГЛАВНАЯ ПРОГРАММА ================
main proc
    mov dx, offset menu_msg
    call print
    mov ah, 1
    int 21h
    cmp al, '1'
    je create_mode
    cmp al, '2'
    je load_mode
    jmp exit

create_mode:
    mov dx, offset fig_msg
    call print
    mov ah, 1
    int 21h
    sub al, '0'
    mov figure_type, al

    mov dx, offset filename_msg
    call print
    mov dx, offset filename
    mov byte ptr [filename], 19
    call input_string
    mov bl, [filename+1]
    mov byte ptr [filename+bx+2], 0

    mov dx, offset click_msg
    call print
    mov ah, 0
    int 16h

    mov al, 13h
    call set_video_mode

    cmp figure_type, 1
    jne try_rhombus_main
    call draw_square
    jmp wait_loop_main
try_rhombus_main:
    cmp figure_type, 2
    jne try_triangle_main
    call draw_rhombus
    jmp wait_loop_main
try_triangle_main:
    cmp figure_type, 3
    jne try_star_main
    call draw_triangle
    jmp wait_loop_main
try_star_main:
    cmp figure_type, 4
    jne draw_trap_main
    call draw_star_fast
    jmp wait_loop_main
draw_trap_main:
    call draw_trapezoid

wait_loop_main:
    call init_mouse
    call show_mouse

wait_click_again_main:
    call wait_left_click
    call hide_mouse

    push cx
    push dx
    cmp figure_type, 1
    jne check_fig2
    call hit_square
    jmp after_check_main
check_fig2:
    cmp figure_type, 2
    jne check_fig3
    call hit_rhombus
    jmp after_check_main
check_fig3:
    cmp figure_type, 3
    jne check_fig4
    call hit_triangle_fast
    jmp after_check_main
check_fig4:
    cmp figure_type, 4
    jne check_fig5
    call hit_star
    jmp after_check_main
check_fig5:
    call hit_trapezoid

after_check_main:
    pop dx
    pop cx
    test al, al
    jz miss_main

    call save_ris
    mov dx, offset ok_msg
    call print
    mov ah, 0
    int 16h
    mov al, 3
    call set_video_mode
    jmp exit

miss_main:
    mov dx, offset not_inside_msg
    call print
    call show_mouse
    jmp wait_click_again_main

load_mode:
    mov dx, offset filename_msg
    call print
    mov dx, offset filename
    mov byte ptr [filename], 19
    call input_string
    mov bl, [filename+1]
    mov byte ptr [filename+bx+2], 0

    mov al, 13h
    call set_video_mode
    mov si, offset filename+2
    call load_ris

    mov dx, offset anykey_msg
    call print
    mov ah, 0
    int 16h
    mov al, 3
    call set_video_mode

exit:
    mov ah, 4Ch
    int 21h
main endp

end start