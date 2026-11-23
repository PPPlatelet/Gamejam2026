## 游戏内剧情 + 出兵剧本（合并版）。
##
## 每条 = 一句台词 + 可选的出兵；when 条件满足时一起触发。
## 同一个 when 的连续几条算一组对话，字幕层按顺序播；出兵写在组的第一条上。
##
## 字段：
##   id       唯一名字，改名会重新播
##   when     触发情况：time / start / kills / reached / base_hp / units / supplies / unit_died
##   where    出现位置：top / center / bottom / left / right
##   text     台词，30 字以内
##   seconds  停留秒数，默认 5
##   spawn    出兵（可选）：{"small": 2, "sword": 1, "charge": 1, "bomb": 1}
##            small=倭寇小船、sword=倭刀船、charge=冲锋船、bomb=炸弹船；
##            同一波逐个出，间隔 0.35 秒
##   once     默认 true；写 false 时按 cooldown 秒重复
##
## 手动测试出兵：L 随机出怪；按住 J 再按 1~4 出指定敌人。

const LINES := [
	# ---------------------------------------------------------------- 第一波：雾起
	{
		"id": "w1_1",
		"when": {"type": "time", "seconds": 3.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 2},
		"text": "旗官沈七：雾里有黑影，不是渔船。",
	},
	{
		"id": "w1_2",
		"when": {"type": "time", "seconds": 3.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "哨船老周：哨船落了帆，灯压到最低。",
	},
	{
		"id": "w1_3",
		"when": {"type": "time", "seconds": 3.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：鸟铳上火，铳口擦干了。",
	},
	{
		"id": "w1_4",
		"when": {"type": "time", "seconds": 3.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：佛郎机装药完毕，等旗令。",
	},
	{
		"id": "w1_5",
		"when": {"type": "time", "seconds": 3.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：放！",
	},

	# ---------------------------------------------------------------- 第二波：刀船
	{
		"id": "w2_1",
		"when": {"type": "time", "seconds": 30.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 3, "sword": 1},
		"text": "哨船老周：敌船分了两路，刀船在前。",
	},
	{
		"id": "w2_2",
		"when": {"type": "time", "seconds": 30.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：刀船近身会缠人，别让它们贴上来。",
	},
	{
		"id": "w2_3",
		"when": {"type": "time", "seconds": 30.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：火箭先点刀船。",
	},
	{
		"id": "w2_4",
		"when": {"type": "time", "seconds": 30.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：炮口转到左舷。",
	},

	# ---------------------------------------------------------------- 第三波：冲锋船
	{
		"id": "w3_1",
		"when": {"type": "time", "seconds": 55.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"charge": 1, "small": 3},
		"text": "哨船老周：中间那条船挂着号旗，在给敌船递令。",
	},
	{
		"id": "w3_2",
		"when": {"type": "time", "seconds": 55.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：那是冲锋船，先打它。",
	},
	{
		"id": "w3_3",
		"when": {"type": "time", "seconds": 55.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：炮位够不着，得往前挪。",
	},
	{
		"id": "w3_4",
		"when": {"type": "time", "seconds": 55.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：我压着，你们动。",
	},

	# ---------------------------------------------------------------- 第四波：炸弹船
	{
		"id": "w4_1",
		"when": {"type": "time", "seconds": 80.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"bomb": 2, "small": 2},
		"text": "哨船老周：两条船不点灯，直直冲过来。",
	},
	{
		"id": "w4_2",
		"when": {"type": "time", "seconds": 80.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：是炸弹船，别让它靠上寨墙。",
	},
	{
		"id": "w4_3",
		"when": {"type": "time", "seconds": 80.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：火箭拦一下！",
	},
	{
		"id": "w4_4",
		"when": {"type": "time", "seconds": 80.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：炸了就炸了，墙还撑得住。",
	},

	# ---------------------------------------------------------------- 第五波：总攻
	{
		"id": "w5_1",
		"when": {"type": "time", "seconds": 110.0},
		"where": "center",
		"seconds": 4.5,
		"spawn": {"sword": 2, "charge": 1, "bomb": 1},
		"text": "哨船老周：雾散了，敌船全压上来。",
	},
	{
		"id": "w5_2",
		"when": {"type": "time", "seconds": 110.0},
		"where": "center",
		"seconds": 4.5,
		"text": "旗官沈七：各船就位，这一波不退。",
	},
	{
		"id": "w5_3",
		"when": {"type": "time", "seconds": 110.0},
		"where": "center",
		"seconds": 4.5,
		"text": "炮船陈九：火药还有两桶。",
	},
	{
		"id": "w5_4",
		"when": {"type": "time", "seconds": 110.0},
		"where": "center",
		"seconds": 4.5,
		"text": "火箭船阿满：够打到最后一条。",
	},

	# ---------------------------------------------------------------- 事件台词（不跟着出兵）
	{
		"id": "first_kill",
		"when": {"type": "kills", "count": 1},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：中了！火油烧起来了。",
	},
	{
		"id": "lost_ship",
		"when": {"type": "unit_died", "count": 1},
		"where": "center",
		"seconds": 5.0,
		"text": "哨船老周：哨船……断了缆。",
	},
	{
		"id": "base_low",
		"when": {"type": "base_hp", "below": 10},
		"where": "top",
		"seconds": 5.0,
		"text": "旗官沈七：寨门裂了，狼烟升起来。",
	},
	{
		"id": "reached_one",
		"when": {"type": "reached", "count": 1},
		"where": "top",
		"seconds": 4.0,
		"text": "哨船老周：有一艘撞上寨墙了，船壳在震。",
	},
	{
		"id": "dawn",
		"when": {"type": "time", "seconds": 150.0},
		"where": "center",
		"seconds": 6.0,
		"text": "旁白：潮水退去，海面只剩碎木和浮油。",
	},
]
