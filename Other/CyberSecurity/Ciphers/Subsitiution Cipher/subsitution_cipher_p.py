#Menue
# -> Encode/Decode
#    ->Encode
#          -> Steps and direction
#          -> Enter and encode
#    ->Decode
#          -> Enter steps and direction
#          -> Press start
#          -> Try again?
# -> Download?
#     ->Yes/No
#          -> Yes
#               -> Download on computer
# -> Ask for another cyber
#      -> Yes
#             ->Repeat
#      ->No
#             -End



######################################################################################################

#Imports

#GUI

#Functions

'''Possible snipbits
import tkinter as tk
from tkinter import messagebox

alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
mapping = {}

def assign_letter(letter):
    selected.set(letter)

def map_letter(letter):
    source = selected.get()
    if source:
        if letter in mapping.values():
            messagebox.showerror("Conflict", f"{letter} already assigned!")
            return
        mapping[source] = letter
        update_mapping()
        selected.set('')

def update_mapping():
    for btn in buttons:
        letter = btn['text']
        mapped = mapping.get(letter, '_')
        btn.config(text=f"{letter}\n→ {mapped}")

root = tk.Tk()
root.title("Substitution Cipher Mapper")

selected = tk.StringVar()
buttons = []

for i, letter in enumerate(alphabet):
    btn = tk.Button(root, text=f"{letter}\n→ _", width=5, height=3,
                    command=lambda l=letter: assign_letter(l))
    btn.grid(row=i//9, column=i%9, padx=5, pady=5)
    buttons.append(btn)

# Mapped letter input row
for i, letter in enumerate(alphabet):
    btn = tk.Button(root, text=letter, width=3,
                    command=lambda l=letter: map_letter(l))
    btn.grid(row=3, column=i%26, padx=2)

tk.Label(root, text="Selected:").grid(row=4, column=0)
tk.Label(root, textvariable=selected).grid(row=4, column=1)

root.mainloop()
'''
