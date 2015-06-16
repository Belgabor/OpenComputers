
function xyz(a)
  a["x"] = "B"
end

b = {}
xyz(b)
print(b["x"])