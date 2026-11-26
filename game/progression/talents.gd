extends RefCounted

# id, domain, name, cost, parent, effect, magnitude, description, secret
const NODES := [["vitality",0,"Vitality",25,"","hp",15,"+15 max HP",false],["brutality",0,"Brutality",40,"vitality","damage",0.15,"+15% melee damage",false],["wind",0,"Second Wind",40,"vitality","active",0,"Restore 35 stamina (15s)",false],["sword",1,"Sword Mastery",25,"","weapon",0.15,"+15% sword damage",false],["quick",1,"Quick Blade",40,"sword","speed",0.2,"20% shorter sword cycle",false],["flurry",1,"Flurry",40,"sword","active",0,"Next sword hit +60% damage (8s)",false],["axe",2,"Axe Mastery",25,"","weapon",0.15,"+15% axe damage",false],["efficient",2,"Efficient Swing",40,"axe","cost",0.2,"20% less axe stamina",false],["rage",2,"Rage",40,"axe","active",0,"Next axe hit +80% damage (12s)",false],["spear",3,"Spear Mastery",25,"","weapon",0.15,"+15% spear damage",false],["reach",3,"Long Reach",40,"spear","reach",0.6,"+0.6m spear reach",false],["lunge",3,"Lunge",40,"spear","active",0,"Next spear attack +2m reach (8s)",false],["guard",4,"Guard",25,"","block",0.2,"20% less block stamina",false],["bulwark",4,"Bulwark",40,"guard","reduction",0.08,"8 percentage points extra block",false],["fortify",4,"Fortify",40,"guard","active",0,"50% damage reduction for 4s (18s)",false],["footwork",5,"Footwork",25,"","move",0.1,"+10% movement speed",false],["evasion",5,"Evasion",40,"footwork","mitigation",0.1,"10% damage reduction",false],["dash",5,"Dash",40,"footwork","active",0,"Double movement speed for 1s (8s)",false],["forgotten",1,"Forgotten Edge",50,"sword","weapon",0.2,"+20% sword damage",true],["stone",0,"Blood of Stone",50,"vitality","hp",20,"+20 max HP",true],["ancient",4,"Ancient Guard",50,"guard","reduction",0.05,"5 percentage points extra block",true]]

static func find(id: String) -> Array:
	for node in NODES:
		if node[0] == id:
			return node
	return []
