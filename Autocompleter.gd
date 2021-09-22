extends Node
class_name Autocompleter


const _target_types:Dictionary = {_EXTENDS = "extends", _VAR = "var", _FUNC = "func"}

var words_anywhere:PoolStringArray = []
var classes_name:PoolStringArray = []
var list:ItemList = null
var text_edit:TextEdit = null
var target_word_to_change:String = ""
var target_line:String = ""
var locked_text_edit:bool = false

func initialize(target:Node) -> void:
	
	text_edit = target	
	register_api()
	
	words_anywhere.append_array( target.KEYWORDS )
	
	list = target.get_tree().get_nodes_in_group("LIST")[0]
	list.connect("item_selected",self,"on_list_item_selected")
	
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
		classes_name.append(value.name) #register all godot classes
		text_edit.add_keyword_color(value.name, text_edit.CLASS_COLOR)
		print("registering: ", value.name)
		if value.name == "Node":
			print("Found node")
			for method in value.methods:
				print(method.name)
				if method.is_virtual == true:
					words_anywhere.append(method.name)
	
	pass

func cursor_pos_system() -> void:
	
	text_edit.grab_focus()
	text_edit.cursor_set_line(0)
	text_edit.cursor_set_column(0)


func _search_similar(word:String) -> PoolStringArray:
	var result:PoolStringArray = []
	print("target line: ", target_line)
	var target_similars:PoolStringArray = words_anywhere
	
	match target_line:
		_target_types._VAR:
			if not ":" in word:
				target_similars = []
				continue
			word = word.split(":")[1]
			target_similars.append_array(classes_name)
			
		_target_types._EXTENDS:
			target_similars = classes_name
			pass
#	print(target_similars)
	for w in target_similars:
		if !word.begins_with(w[0]): continue
		if word.similarity(w) > .2:
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
		elif event.pressed && (event.scancode == KEY_ENTER or event.scancode == KEY_TAB ):
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
			
			var result:String = "%s "
			match target_line:
				"func":
					result = "%s():\n\t"
				"var":
					result = "%s = "
#			print("resulting target line:|", target_line)
			
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
	
	if "\t" in line_text:
		line_text = line_text.replace("\t","")
	if " " in line_text:
		line_text = line_text.split(" ")[0]
	target_line = ""
	for value in _target_types:
		if _target_types[value] == line_text:
			target_line = line_text
			break
	print("target line is: ", target_line)
	pass

func on_update_src(src:String) -> void:
#	print("src update\n\n" + src)
	#Find target class (To show all functions from that class and its parents)
	
	var reg:RegEx = RegEx.new()
	reg.compile("extends (?<cn>\\w+)")
	var result = reg.search(src)
	if result:
		var target_class:String = result.get_string("cn")
		print("target class: ", target_class)
	
	# Find all fuctions from this src, to autocomplete if user calls one of them
	reg.compile("func (?<n>\\w+)")
	result = reg.search_all(src)
	if result:
		
		for found in result:
			var f:RegExMatch = found
			print("found function: ", f.get_string("n"))
		pass
		
#	print("src update done")
	
	pass



func on_list_item_selected(index:int) -> void:
	if list.get_item_count() <= 0: return
	target_word_to_change = list.get_item_text(index)
	print("targ: ", target_word_to_change)
	print("what")
	pass

func on_incoming_word(word:String,line_text:String) -> void:
	if locked_text_edit: return
	_update_target_line_type(line_text)
	list.clear()
	var suggestions = _search_similar(word)
	var selected_index:int = 0
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
				selected_index = i
			elif string.similarity(word) < .5:
				list.remove_item(i)
		list.select(selected_index)
		list.emit_signal("item_selected",selected_index)
			
	else:
		list.visible = false

