; ----------------------------------------------------------------------
; Copyright © 2023 End45
; 
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
; 
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; 
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.
; ----------------------------------------------------------------------

; FixMemorySoftlock v2

; This patch modifies the behaviour of the game when it fails to allocate a new block of memory while trying to load a WAN file. Instead of crashing, it will use a default
; sprite stored in the extra overlay.

; This file is intended to be used with armips v0.11
; The patch "ExtraSpace.asm" must be applied before this one
; Required ROM: Explorers of Sky (EU/US/JP)
; Required files: arm9.bin, overlay_0036.bin

.nds
.include "common/regionSelect.asm"

.open "overlay_0036.bin", ov_36
.orga 0x780
.area 0x9C

; -----------------
; Called when the game fails to load a sprite
; Available registers: At least r0-r3
; -----------------
memFailHook:
	; Check if we came from LoadWanTableEntryFromPack
	; r0 = Return address
	ldr r0,[sp,44h]
	ldr r1,=EU_201D5F0 ; Return address for uncompressed WAN files
	cmp r0,r1
	moveq r2,0h
	beq @@setDefaultSprite
	ldr r1,=EU_201D5C4 ; Return address for WAN files compressed with AT compression
	cmp r0,r1
	moveq r2,1h
	beq @@setDefaultSprite
	; If it's none of those, return null and hope for the best
	
	; No idea what this is, but it must be called before exiting MemLocateSet or the game softlocks
	ldr r0,=EU_20AF7A8
	bl EU_2002E98
	mov r0,0h
	add sp,sp,20h
	pop r3-r11,pc
@@setDefaultSprite:
	; Simulate a return from MemLocateSet
	ldr r0,=EU_20AF7A8
	push r2 ; We need this for the check ahead
	bl EU_2002E98
	pop r2
	add sp,sp,20h
	pop r3-r11,lr
	
	; Recreate the relevant functions from the last part of LoadWanTableEntryFromPack, but instead of loading a WAN into a newly allocated memory area,
	; we point to the default sprite.
	; r2 = 1 if the sprite to load was compressed. If it's not, we need to run an additional instruction from the original code
	cmp r2,0h
	; [r4+28h]: Sprite size
	moveq r9,3C0h
	streq r9,[r4,28h]
	; [r4+34h]: Pointer to the start of the SIRO file containing the sprite
	ldr r0,=defaultSprite
	str r0,[r4,34h]
	; Original code
	ldrsh r1,[r4,2Ch]
	add r1,r1,1h
	strh r1,[r4,2Ch]
	; [r4+30h]: Pointer to the SIRO content header
	add r0,r0,388h
	str r0,[r4,30h]
	
	; Return from LoadWanTableEntryFromPack
	mov r0,r5
	pop r3-r9,pc
.pool

.endarea

.orga 0x1420
.area 0x394

; Default sprite to use as a replacement. It's a SIRO file, so it's offsets are already RAM-relative. No need to convert it, and no need for the encoded pointer table
; at the end (the pointer to the encoded pointer table points at garbage because of this, but I don't think it's used for anything once the file has been converted).
defaultSprite:
.byte 0x53, 0x49, 0x52, 0x4F, 0x28, 0x88, 0x3A, 0x02, 0x40, 0x88, 0x3A, 0x02, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0xF8, 0x01, 0xF8, 0x48, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0xFC, 0xFF, 0x00, 0x00, 0xFC, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0xAA, 0xAA, 0x00, 0x00, 0x00, 0x00, 0x10, 0x11, 0x11, 0x11, 0x10, 0x11, 0x11, 0x11, \
	  0x10, 0x11, 0x11, 0x11, 0x10, 0x11, 0x11, 0x11, 0x10, 0x11, 0x11, 0x11, 0x10, 0x11, 0x11, 0x11, \
	  0x10, 0x11, 0x11, 0x11, 0x00, 0x00, 0x00, 0x00, 0x22, 0x22, 0x22, 0x02, 0x22, 0x22, 0x22, 0x02, \
	  0x22, 0x22, 0x22, 0x02, 0x22, 0x22, 0x22, 0x02, 0x22, 0x22, 0x22, 0x02, 0x22, 0x22, 0x22, 0x02, \
	  0x22, 0x22, 0x22, 0x02, 0x20, 0x22, 0x22, 0x22, 0x20, 0x22, 0x22, 0x22, 0x20, 0x22, 0x22, 0x22, \
	  0x20, 0x22, 0x22, 0x22, 0x20, 0x22, 0x22, 0x22, 0x20, 0x22, 0x22, 0x22, 0x20, 0x22, 0x22, 0x22, \
	  0x00, 0x00, 0x00, 0x00, 0x11, 0x11, 0x11, 0x01, 0x11, 0x11, 0x11, 0x01, 0x11, 0x11, 0x11, 0x01, \
	  0x11, 0x11, 0x11, 0x01, 0x11, 0x11, 0x11, 0x01, 0x11, 0x11, 0x11, 0x01, 0x11, 0x11, 0x11, 0x01, \
	  0x00, 0x00, 0x00, 0x00, 0xD4, 0x84, 0x3A, 0x02, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0xFF, 0x80, \
	  0xFF, 0x00, 0xDC, 0x80, 0x00, 0x00, 0x00, 0x80, 0x20, 0xA9, 0x20, 0x80, 0x41, 0x75, 0x64, 0x80, \
	  0x69, 0x6E, 0x6F, 0x80, 0x20, 0x32, 0x30, 0x80, 0x32, 0x31, 0x20, 0x80, 0x20, 0xA9, 0x20, 0x80, \
	  0x41, 0x75, 0x64, 0x80, 0x69, 0x6E, 0x6F, 0x80, 0x20, 0x32, 0x30, 0x80, 0x32, 0x31, 0x20, 0x80, \
	  0x20, 0xA9, 0x20, 0x80, 0x41, 0x75, 0x64, 0x80, 0x69, 0x6E, 0x6F, 0x80, 0x6C, 0x85, 0x3A, 0x02, \
	  0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0xB0, 0x84, 0x3A, 0x02, \
	  0xF8, 0xFF, 0x07, 0x00, 0x07, 0x00, 0xF8, 0xFF, 0x07, 0x00, 0x07, 0x00, 0xF8, 0xFF, 0xF8, 0xFF, \
	  0xBA, 0x84, 0x3A, 0x02, 0xBA, 0x84, 0x3A, 0x02, 0xBA, 0x84, 0x3A, 0x02, 0xBA, 0x84, 0x3A, 0x02, \
	  0xBA, 0x84, 0x3A, 0x02, 0xBA, 0x84, 0x3A, 0x02, 0xBA, 0x84, 0x3A, 0x02, 0xBA, 0x84, 0x3A, 0x02, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xD0, 0x85, 0x3A, 0x02, \
	  0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x54, 0x85, 0x3A, 0x02, \
	  0xBC, 0x85, 0x3A, 0x02, 0xC0, 0x85, 0x3A, 0x02, 0x9C, 0x86, 0x3A, 0x02, 0x2C, 0x00, 0x01, 0x00, \
	  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0x87, 0x3A, 0x02, 0xAC, 0x85, 0x3A, 0x02, \
	  0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x88, 0x3A, 0x02, 0x18, 0x88, 0x3A, 0x02, \
	  0x01, 0x00, 0x00, 0x00
.endarea

.close


.open "arm9.bin", arm9
; -----------------
; Undo hook from the 1.X version of the patch
; -----------------
.org EU_2001238
	ldr r0,[pc,2Ch]

; -----------------
; Hook failure branch on MemLocateSet
; -----------------
.org EU_20015DC
	bl memFailHook

.close