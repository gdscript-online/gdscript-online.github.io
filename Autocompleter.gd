extends Node
class_name Autocompleter



var words:PoolStringArray = []
var list:ItemList = null
var text_edit:TextEdit = null
var target_word_to_change:String = ""
var target_line:String = ""
var locked_text_edit:bool = false

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
		if event.pressed && event.scancode == KEY_DOWN:
			_select_next(1)
		elif event.pressed && event.scancode == KEY_UP:
			_select_next(-1)
		elif event.pressed && event.scancode == KEY_ENTER:
			locked_text_edit = true
			
			
			list.visible = false
			# == select word and replace by the suggested one
			var target_column:int = text_edit.cursor_get_column() - 1
			text_edit.cursor_set_column(target_column)
			var word:String = text_edit.get_word_under_cursor()
			target_column -= word.length()-1
			text_edit.cursor_set_column(target_column)
#			print("word under cursor: ", word)
			text_edit.select(text_edit.cursor_get_line(), target_column, text_edit.cursor_get_line(), target_column + word.length())
			print("line text is: ", target_line)
			var result:String = "%s"
			if target_line == "func": result = "%s():\n\t"
			print("resulting target line:|", target_line)
			
			text_edit.insert_text_at_cursor(result % target_word_to_change)
			
			
			# ==
			
			
			
			# avoid propagating input to the text edit and only works in the autocomplete list
			text_edit.get_tree().set_input_as_handled()
			locked_text_edit = false
		

func _select_next(value:int):
	var items = list.get_item_count()
	if not list.get_selected_items(): return
	var selected:int = list.get_selected_items()[0]
	print("selected: ", selected)
	if value > 0:
		if selected + 1 < items:
			list.select(selected+1)
		else: list.select(0)
	else:
		if selected - 1 < 0:
			list.select(items-1)
		else:
			list.select(selected-1)
	list.emit_signal("item_selected",list.get_selected_items()[0])
	# avoid propagating input to the text edit and only works in the autocomplete list
	text_edit.get_tree().set_input_as_handled()
	pass

func _update_target_line_type(line_text:String) -> void:
	
	line_text = line_text.replace("\t","")
	line_text = line_text.split(" ")[0]
	target_line = line_text
	pass

func on_update_src(src:String) -> void:
	return
	#TODO: Finish This
	var reg:RegEx = RegEx.new()
	reg.compile("extends \\w+")
	var result = reg.search(src)
	if !result: return
	var target_class:String = result.get_string()
	print("target class: ", target_class)
	pass

func on_list_item_selected(index:int) -> void:
	target_word_to_change = list.get_item_text(index)
	print("targ: ", target_word_to_change)
	print("what")
	pass

func on_incoming_word(word:String,line_text:String) -> void:
	if locked_text_edit: return
	_update_target_line_type(line_text)
	list.clear()
	var suggestions = _search_similar(word)
	if suggestions:
		list.rect_position = text_edit.get_cursor_pos()
		list.visible = true
		for i in range(suggestions.size()):
			if word == suggestions[i]: # cover the case where the user already typed the suggestion
				list.visible = false
				break
			list.add_item(suggestions[i])
			var string:String = suggestions[i]
			if string.similarity(word) > .5:
				list.select(i)
		list.select(0)
		list.emit_signal("item_selected",0)
			
	else:
		list.visible = false

