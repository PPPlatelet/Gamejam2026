## 出兵时间表：和字幕完全独立，到点就在指定出生格出怪。
##
## 每条：
##   "time"   开局后第几秒出这一波
##   "spawn"  出什么：{"small": 4, "sword": 2, "charge": 1, "bomb": 1}
##            small=倭寇小船、sword=倭刀船、charge=冲锋船、bomb=炸弹船
##
## 所有敌人从 Game 的 spawn_cell 那一个格子出生（棋盘上被挡住时会就近换格）；
## 同一波逐个出，间隔 0.35 秒；数量再乘 Game 的 wave_scale。
##
## 改这里只会影响出怪，不影响台词；台词在 story_lines.gd。

const WAVES := [
	{"time": 10.0, "spawn": {"small": 4}},
	{"time": 70.0, "spawn": {"small": 4}},
	{"time": 140.0, "spawn": {"small": 4, "sword": 2}},
	{"time": 210.0, "spawn": {"small": 6, "sword": 2}},
	{"time": 280.0, "spawn": {"small": 4, "sword": 3}},
	{"time": 350.0, "spawn": {"small": 4, "sword": 3, "charge": 2}},
	{"time": 420.0, "spawn": {"small": 6, "sword": 3, "charge": 2}},
	{"time": 490.0, "spawn": {"small": 6, "sword": 3, "bomb": 2}},
	{"time": 560.0, "spawn": {"small": 7, "sword": 4, "bomb": 2}},
	{"time": 630.0, "spawn": {"small": 7, "sword": 4, "charge": 2, "bomb": 2}},
	{"time": 710.0, "spawn": {"small": 7, "sword": 4, "bomb": 3}},
	{"time": 790.0, "spawn": {"small": 7, "sword": 4, "charge": 2, "bomb": 2}},
	{"time": 860.0, "spawn": {"small": 8, "sword": 6, "charge": 2, "bomb": 3}},
]
