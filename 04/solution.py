#!/usr/bin/env python3
mat = open("input").read().splitlines()
print(sum(all(mat[i+[[0,0,0,0],[0,1,2,3],[0,-1,-2,-3]][a][c]][j+[[0,0,0,0],[0,1,2,3],[0,-1,-2,-3]][b][c]]=="XMAS"[c] for c in range(4)) for a,b in ((0,1),(0,2),(1,0),(1,1),(1,2),(2,0),(2,1),(2,2)) for i in [range(len(mat)), range(len(mat)-3), range(3,len(mat))][a] for j in [range(len(mat[0])), range(len(mat[0])-3), range(3,len(mat[0]))][b]))
#print(sum(mat[i][j] == "A" and (((mat[i-1][j-1] == "M" and mat[i+1][j+1] == "S") or (mat[i-1][j-1] == "S" and mat[i+1][j+1] == "M")) and ((mat[i+1][j-1] == "M" and mat[i-1][j+1] == "S") or (mat[i+1][j-1] == "S" and mat[i-1][j+1] == "M"))) for i in range(1,len(mat)-1) for j in range(1,len(mat[0])-1)))
