
with open(r'd:\Laptrinhmobile_tools\CT KHDL\lib\screens\agent_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.splitlines()
stack = []
for i, line in enumerate(lines):
    for char in line:
        if char == '{':
            stack.append(i + 1)
        elif char == '}':
            if stack:
                stack.pop()
            else:
                print(f"Extra closing brace at line {i + 1}")

if stack:
    print(f"Missing closing braces for starts at lines: {stack}")
else:
    print("Braces are balanced")
