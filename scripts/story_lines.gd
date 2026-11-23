## 游戏内剧情 + 出兵剧本（合并版，15 分钟一局）。
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
## 15 分钟流程：前 5 分钟试探与刀船，5~10 分钟冲锋船与炸弹船，
## 10 分钟后三面总攻，14:50 收尾，15:00 判胜利（base 还在）。
##
## 手动测试出兵：L 随机出怪；按住 J 再按 1~4 出指定敌人。

const LINES := [
	# ---------------------------------------------------------------- 第一波：雾起（0:10）
	{
		"id": "w1_1",
		"when": {"type": "time", "seconds": 10.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 4},
		"text": "旗官沈七：雾里有黑影，不是渔船。",
	},
	{
		"id": "w1_2",
		"when": {"type": "time", "seconds": 10.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "哨船老周：哨船落了帆，灯压到最低。",
	},
	{
		"id": "w1_3",
		"when": {"type": "time", "seconds": 10.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：鸟铳上火，铳口擦干了。",
	},
	{
		"id": "w1_4",
		"when": {"type": "time", "seconds": 10.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：佛郎机装药完毕，等旗令。",
	},
	{
		"id": "w1_5",
		"when": {"type": "time", "seconds": 10.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：放！",
	},

	# ---------------------------------------------------------------- 第二波：试探（1:10）
	{
		"id": "w2_1",
		"when": {"type": "time", "seconds": 70.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 4},
		"text": "哨船老周：第二拨，还是小船。",
	},
	{
		"id": "w2_2",
		"when": {"type": "time", "seconds": 70.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：放近再打。",
	},
	{
		"id": "w2_3",
		"when": {"type": "time", "seconds": 70.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：铳口一直热着。",
	},

	# ---------------------------------------------------------------- 第三波：刀船（2:20）
	{
		"id": "w3_1",
		"when": {"type": "time", "seconds": 140.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 4, "sword": 2},
		"text": "哨船老周：刀船混在小船里。",
	},
	{
		"id": "w3_2",
		"when": {"type": "time", "seconds": 140.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：刀船近身会缠人，别让它贴上来。",
	},
	{
		"id": "w3_3",
		"when": {"type": "time", "seconds": 140.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：火箭先点刀船。",
	},
	{
		"id": "w3_4",
		"when": {"type": "time", "seconds": 140.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：炮口转左舷。",
	},

	# ---------------------------------------------------------------- 第四波：浅滩（3:30）
	{
		"id": "w4_1",
		"when": {"type": "time", "seconds": 210.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 6, "sword": 2},
		"text": "哨船老周：它们贴着浅滩走，想绕开哨船。",
	},
	{
		"id": "w4_2",
		"when": {"type": "time", "seconds": 210.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：让哨船卡住水道。",
	},
	{
		"id": "w4_3",
		"when": {"type": "time", "seconds": 210.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：炮位跟过去。",
	},

	# ---------------------------------------------------------------- 第五波：刀船增多（4:40）
	{
		"id": "w5_1",
		"when": {"type": "time", "seconds": 280.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 4, "sword": 3},
		"text": "哨船老周：刀船又多了两艘。",
	},
	{
		"id": "w5_2",
		"when": {"type": "time", "seconds": 280.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：哨船顶住，别退。",
	},
	{
		"id": "w5_3",
		"when": {"type": "time", "seconds": 280.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：我换药，很快。",
	},

	# ---------------------------------------------------------------- 第六波：冲锋船（5:50）
	{
		"id": "w6_1",
		"when": {"type": "time", "seconds": 350.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 4, "sword": 3, "charge": 2},
		"text": "哨船老周：中间那条挂着号旗，在给敌船递令。",
	},
	{
		"id": "w6_2",
		"when": {"type": "time", "seconds": 350.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：冲锋船，先打它。",
	},
	{
		"id": "w6_3",
		"when": {"type": "time", "seconds": 350.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：炮位够不着，得往前挪。",
	},
	{
		"id": "w6_4",
		"when": {"type": "time", "seconds": 350.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：我压着，你们动。",
	},

	# ---------------------------------------------------------------- 第七波（7:00）
	{
		"id": "w7_1",
		"when": {"type": "time", "seconds": 420.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 6, "sword": 3, "charge": 2},
		"text": "哨船老周：号旗倒了，敌船慢下来了。",
	},
	{
		"id": "w7_2",
		"when": {"type": "time", "seconds": 420.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：趁现在，把刀船清掉。",
	},
	{
		"id": "w7_3",
		"when": {"type": "time", "seconds": 420.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：炮口补位。",
	},

	# ---------------------------------------------------------------- 第八波：炸弹船（8:10）
	{
		"id": "w8_1",
		"when": {"type": "time", "seconds": 490.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 6, "sword": 3, "bomb": 2},
		"text": "哨船老周：两条船不点灯，直直冲过来。",
	},
	{
		"id": "w8_2",
		"when": {"type": "time", "seconds": 490.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：炸弹船，别让它靠上寨墙。",
	},
	{
		"id": "w8_3",
		"when": {"type": "time", "seconds": 490.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：火箭拦一下！",
	},
	{
		"id": "w8_4",
		"when": {"type": "time", "seconds": 490.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：炸了就炸了，墙还撑得住。",
	},

	# ---------------------------------------------------------------- 第九波（9:20）
	{
		"id": "w9_1",
		"when": {"type": "time", "seconds": 560.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 7, "sword": 4, "bomb": 2},
		"text": "哨船老周：寨墙外水浅，它们只能排成一列。",
	},
	{
		"id": "w9_2",
		"when": {"type": "time", "seconds": 560.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：把这一列放进来打。",
	},
	{
		"id": "w9_3",
		"when": {"type": "time", "seconds": 560.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：火药够。",
	},

	# ---------------------------------------------------------------- 第十波（10:30）
	{
		"id": "w10_1",
		"when": {"type": "time", "seconds": 630.0},
		"where": "bottom",
		"seconds": 4.0,
		"spawn": {"small": 7, "sword": 4, "charge": 2, "bomb": 2},
		"text": "哨船老周：雾又厚了，看不清船数。",
	},
	{
		"id": "w10_2",
		"when": {"type": "time", "seconds": 630.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "旗官沈七：不管多少，守住水道。",
	},
	{
		"id": "w10_3",
		"when": {"type": "time", "seconds": 630.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "炮船陈九：炮位不能停。",
	},
	{
		"id": "w10_4",
		"when": {"type": "time", "seconds": 630.0},
		"where": "bottom",
		"seconds": 4.0,
		"text": "火箭船阿满：铳管换过三回了。",
	},

	# ---------------------------------------------------------------- 第十一波：总攻（11:50）
	{
		"id": "w11_1",
		"when": {"type": "time", "seconds": 710.0},
		"where": "center",
		"seconds": 4.5,
		"spawn": {"small": 7, "sword": 4, "bomb": 3},
		"text": "哨船老周：敌船全压上来了，号旗一面接一面。",
	},
	{
		"id": "w11_2",
		"when": {"type": "time", "seconds": 710.0},
		"where": "center",
		"seconds": 4.5,
		"text": "旗官沈七：各船就位，这一波不退。",
	},
	{
		"id": "w11_3",
		"when": {"type": "time", "seconds": 710.0},
		"where": "center",
		"seconds": 4.5,
		"text": "炮船陈九：火药还有两桶。",
	},
	{
		"id": "w11_4",
		"when": {"type": "time", "seconds": 710.0},
		"where": "center",
		"seconds": 4.5,
		"text": "火箭船阿满：够打到最后一条。",
	},

	# ---------------------------------------------------------------- 第十二波（13:10）
	{
		"id": "w12_1",
		"when": {"type": "time", "seconds": 790.0},
		"where": "center",
		"seconds": 4.5,
		"spawn": {"small": 7, "sword": 4, "charge": 2, "bomb": 2},
		"text": "哨船老周：三面都是船影。",
	},
	{
		"id": "w12_2",
		"when": {"type": "time", "seconds": 790.0},
		"where": "center",
		"seconds": 4.5,
		"text": "旗官沈七：哨船前出，炮船居中，火箭船别停。",
	},
	{
		"id": "w12_3",
		"when": {"type": "time", "seconds": 790.0},
		"where": "center",
		"seconds": 4.5,
		"text": "炮船陈九：炮口过热，我浇水。",
	},
	{
		"id": "w12_4",
		"when": {"type": "time", "seconds": 790.0},
		"where": "center",
		"seconds": 4.5,
		"text": "火箭船阿满：打！",
	},

	# ---------------------------------------------------------------- 第十三波：最后一轮（14:20）
	{
		"id": "w13_1",
		"when": {"type": "time", "seconds": 860.0},
		"where": "center",
		"seconds": 4.5,
		"spawn": {"small": 8, "sword": 6, "charge": 2, "bomb": 3},
		"text": "哨船老周：最后一批，全是大家伙。",
	},
	{
		"id": "w13_2",
		"when": {"type": "time", "seconds": 860.0},
		"where": "center",
		"seconds": 4.5,
		"text": "旗官沈七：打完这一轮，潮水就退了。",
	},
	{
		"id": "w13_3",
		"when": {"type": "time", "seconds": 860.0},
		"where": "center",
		"seconds": 4.5,
		"text": "火箭船阿满：别让它们摸到寨门。",
	},

	# ---------------------------------------------------------------- 收尾（14:50，15:00 判胜利）
	{
		"id": "finale_1",
		"when": {"type": "time", "seconds": 890.0},
		"where": "center",
		"seconds": 5.0,
		"text": "旁白：潮水退去，海面只剩碎木和浮油。",
	},
	{
		"id": "finale_2",
		"when": {"type": "time", "seconds": 890.0},
		"where": "center",
		"seconds": 5.0,
		"text": "旗官沈七：把名字刻上木牌，一个都别漏。",
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
]
