## 游戏内穿插的剧情文案（剧本）。
##
## 每条文案的结构：
##   "id"      唯一名字，用来记录这条是否已经播过（改名字就会重新播一次）
##   "when"    触发情况，见下面的说明
##   "where"   出现位置："top"（顶部）/ "center"（屏幕中间）/ "bottom"（底部）/
##             "left"（左上）/ "right"（右侧中间）
##   "text"    文案内容，支持 \n 手动换行（字幕会自动按宽度折行）
##   "seconds" 停留时间（秒），不写默认 5
##   "once"    是否只播一次，默认 true；写成 false 会按 "cooldown" 秒间隔重复
##
## when 支持的写法（挑一个用）：
##   {"type": "start"}                      开局立刻
##   {"type": "time", "seconds": 60}        开局 60 秒后
##   {"type": "spawn", "count": 1}          累计按 L 出怪到 1 个
##   {"type": "kills", "count": 5}          累计击杀到 5 个
##   {"type": "reached", "count": 1}        敌人累计抵达基地 1 个
##   {"type": "base_hp", "below": 10}       基地血量 ≤ 10
##   {"type": "units", "count": 3}          场上船的数量 ≥ 3
##   {"type": "supplies", "count": 100}     粮草 ≥ 100
##   {"type": "unit_died", "count": 1}      累计被摧毁 1 艘船
##   {"type": "game_over"}                  失败（会先弹失败页，慎用）
##
## 改文案只需要改这个文件，不用动别的地方。

const LINES := [
	{
		"id": "opening",
		"when": {"type": "start"},
		"where": "top",
		"seconds": 6.0,
		"text": "海图尽头的雾海里，只剩这一座基地还亮着灯。",
	},
	{
		"id": "first_enemy",
		"when": {"type": "spawn", "count": 1},
		"where": "bottom",
		"seconds": 6.0,
		"text": "第一艘敌舰从雾里探出头来——它们循着粮草的味道找过来了。",
	},
	{
		"id": "first_kill",
		"when": {"type": "kills", "count": 1},
		"where": "bottom",
		"seconds": 4.5,
		"text": "敌舰炸成一团火球，沉进了黑水里。",
	},
	{
		"id": "three_units",
		"when": {"type": "units", "count": 3},
		"where": "bottom",
		"seconds": 5.0,
		"text": "三艘船就位。哨船在前，火箭船居中，炮船压阵。",
	},
	{
		"id": "kills_5",
		"when": {"type": "kills", "count": 5},
		"where": "bottom",
		"seconds": 5.0,
		"text": "五艘。海面安静下来，只有浪拍着船壳。",
	},
	{
		"id": "lost_ship",
		"when": {"type": "unit_died", "count": 1},
		"where": "center",
		"seconds": 5.5,
		"text": "我们的船沉了。\n油污在浪里散开，很快又被雾吞掉。",
	},
	{
		"id": "base_hp_low",
		"when": {"type": "base_hp", "below": 10},
		"where": "top",
		"seconds": 6.0,
		"text": "基地的警报响个不停——防线快撑不住了。",
	},
	{
		"id": "supplies_rich",
		"when": {"type": "supplies", "count": 100},
		"where": "left",
		"seconds": 5.0,
		"text": "粮草堆满了舱底。是时候把炮船推上去了。",
	},
	{
		"id": "kills_15",
		"when": {"type": "kills", "count": 15},
		"where": "bottom",
		"seconds": 5.0,
		"text": "第十五艘。敌舰开始绕开哨船，贴着雾边摸过来。",
	},
	{
		"id": "time_60",
		"when": {"type": "time", "seconds": 60.0},
		"where": "center",
		"seconds": 6.0,
		"text": "雾越来越浓。\n下一艘敌舰，不知道会从哪片浪里冒出来。",
	},
	{
		"id": "reached_one",
		"when": {"type": "reached", "count": 1},
		"where": "top",
		"seconds": 5.0,
		"text": "有一艘敌舰撞上了基地。船壳在震，灯在晃。",
	},
]
