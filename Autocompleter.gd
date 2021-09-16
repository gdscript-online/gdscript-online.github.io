extends Node
class_name Autocompleter



var words:PoolStringArray = []
var list:ItemList = null
var text_edit:TextEdit = null
func initialize(target:Node) -> void:
	
	register_api()
	
	words.append_array( target.KEYWORDS )
	
	list = target.get_tree().get_nodes_in_group("LIST")[0]
	list.connect("item_selected",self,"on_list_item_selected")
	
	text_edit = target
	cursor_pos_system()
	target.connect("incoming_word",self,"on_incoming_word")
	target.connect("update_src",self, "on_update_src")
	
	
	pass
var regex = RegEx.new()

func register_api() -> void:
	
	var file:File = File.new()
	var error = file.open("res://api.json",File.READ)
	if error != OK:
		print("Error opening api: ", error)
		return
	var data:Array = JSON.parse(file.get_as_text()).result
	for value in data:
#		print("Name: ", value.name)
		words.append(value.name)
		if value.name == "Node":
			print("Found node")
			for method in value.methods:
				print(method.name)
				words.append(method.name)
	
	pass

func cursor_pos_system() -> void:
	
	text_edit.grab_focus()
	text_edit.cursor_set_line(0)
	text_edit.cursor_set_column(0)
	
	
	pass

func on_incoming_word(word:String) -> void:
	list.clear()
	var suggestions = _search_similar(word)
	if suggestions:
		list.rect_position = text_edit.get_cursor_pos()
		list.visible = true
		
		for i in range(suggestions.size()):
			list.add_item(suggestions[i])
			var string:String = suggestions[i]
			if string.similarity(word) > .5:
				list.select(i)
			
			
	else:
		list.visible = false
	
	
	
	pass

func _search_similar(word:String) -> PoolStringArray:
	var result:PoolStringArray = []
	
	for w in words:
		if !word.begins_with(w[0]): continue
		if word.similarity(w) > .3:
			result.append(w)
	
	return result

func search(string:String) -> PoolStringArray:
	regex.compile("\\w+")
	var result = regex.search_all(string)
	var response:PoolStringArray = []
	for _match in result:
		response.append(_match.get_string())
	return response
	pass

#its called by CursorPos node
func input(event: InputEvent) -> void:
	if event is InputEventKey && list.visible:
		var pos = Vector2(text_edit.cursor_get_column(),text_edit.cursor_get_line())
		if event.pressed && event.scancode == KEY_UP:
			_select_next(1)
		elif event.pressed && event.scancode == KEY_DOWN:
			_select_next(-1)
		elif event.pressed && event.scancode == KEY_ENTER:
#			text_edit.readonly = true
			
			print("whow")
			text_edit.cursor_set_column(pos.x)
			text_edit.cursor_set_line(pos.y)
			text_edit.get_tree().set_input_as_handled()
			
		

func _select_next(value:int):
	print("selected")
	var items = list.get_item_count()
	if value > 0:
		if items + 1 < items:
			list.select(list.get_selected_items()[0]+1)
		else: list.select(0)
	else:
		if items - 1 < 0:
			list.select(items[-1])
		else:
			list.select(list.get_selected_items()[0]-1)
	
	pass

func on_update_src(src:String) -> void:
	print(src)
	pass

func on_list_item_selected(index:int) -> void:
	
	
	
	pass


