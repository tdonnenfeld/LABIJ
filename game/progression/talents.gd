extends RefCounted

# id, domain, name, cost, parent, effect, magnitude, description, secret
const NODES := [["vitality",0,"Vitality",25,"","hp",15,"+15 max HP",false],
	["brutality",0,"Brutality",40,"vitality","damage",0.15,"+15% melee damage",false],
	["wind",0,"Second Wind",40,"vitality","active",0,"Restore 35 stamina (15s)",false],
	["sword",1,"Sword Mastery",25,"","weapon",0.15,"+15% sword damage",false],
	["quick",1,"Quick Blade",40,"sword","speed",0.2,"20% shorter sword cycle",false],
	["flurry",1,"Flurry",40,"sword","active",0,"Next sword hit +60% damage (8s)",false],
	["axe",2,"Axe Mastery",25,"","weapon",0.15,"+15% axe damage",false],
	["efficient",2,"Efficient Swing",40,"axe","cost",0.2,"20% less axe stamina",false],
	["rage",2,"Rage",40,"axe","active",0,"Next axe hit +80% damage (12s)",false],
	["spear",3,"Spear Mastery",25,"","weapon",0.15,"+15% spear damage",false],
	["reach",3,"Long Reach",40,"spear","reach",0.6,"+0.6m spear reach",false],
	["lunge",3,"Lunge",40,"spear","active",0,"Next spear attack +2m reach (8s)",false],
	["guard",4,"Guard",25,"","block",0.2,"20% less block stamina",false],
	["bulwark",4,"Bulwark",40,"guard","reduction",0.08,"8 percentage points extra block",false],
	["fortify",4,"Fortify",40,"guard","active",0,"50% damage reduction for 4s (18s)",false],
	["footwork",5,"Footwork",25,"","move",0.1,"+10% movement speed",false],
	["evasion",5,"Evasion",40,"footwork","mitigation",0.1,"10% damage reduction",false],
	["dash",5,"Dash",40,"footwork","active",0,"Double movement speed for 1s (8s)",false],
	["forgotten",1,"Forgotten Edge",50,"sword","weapon",0.2,"+20% sword damage",true],
	["stone",0,"Blood of Stone",50,"vitality","hp",20,"+20 max HP",true],
	["ancient",4,"Ancient Guard",50,"guard","reduction",0.05,"5 percentage points extra block",true],
	["conditioning",0,"Conditioning",50,"vitality","regen",5,"+5 stamina regenerated per second",false],
	["executioner",0,"Executioner",65,"brutality","execute",0.35,"+35% damage against enemies below 30% HP",false],
	["bloodlust",0,"Bloodlust",65,"wind","heal_kill",8,"Restore 8 HP on a kill",false],
	["keen",1,"Keen Edge",50,"quick","bleed",3,"Sword hits cause 3 damage/s for 4 seconds",false],
	["riposte",1,"Riposte",65,"keen","active",0,"After a block, next sword hit +100% (10s)",false],
	["precision",1,"Precision",50,"flurry","precision",0.3,"+30% damage against recovering foes",false],
	["crush",2,"Crushing Blow",50,"efficient","pierce",0.6,"Ignore 60% of enemy armor with axes",false],
	["cleave",2,"Cleave",65,"rage","active",0,"Next axe swing hits all targets in arc (10s)",false],
	["heavy",2,"Heavy Impact",65,"crush","stagger",0.45,"Axe hits delay enemy attacks by 0.45s",false],
	["pin",3,"Pinning Thrust",50,"reach","stagger",0.5,"Spear hits delay enemy attacks by 0.5s",false],
	["impale",3,"Impale",65,"pin","active",0,"Next spear hit stuns for 2s (12s)",false],
	["piercing",3,"Piercing Point",50,"lunge","pierce",0.5,"Ignore 50% of enemy armor",false],
	["parry",4,"Perfect Guard",50,"bulwark","parry",1,"Block in first 0.25s: no damage",false],
	["bash",4,"Shield Bash",65,"parry","active",0,"Next melee hit stuns for 2s (12s)",false],
	["counter",4,"Counterguard",50,"fortify","block_restore",5,"Restore 5 stamina on blocks",false],
	["lightfoot",5,"Lightfoot",50,"evasion","mitigation",0.1,"10% additional damage reduction",false],
	["escape",5,"Escape Step",65,"dash","active",0,"75% damage reduction for 2s (15s)",false],
	["momentum",5,"Momentum",50,"dash","regen",4,"+4 stamina regenerated per second",false]]

static func find(id: String) -> Array:
	for node in NODES:
		if node[0] == id:
			return node
	return []
