class_name SignalSources
extends RefCounted
## 받는 쪽(문·이동 발판·레이저)이 공유하는 규칙 7 처리: sources NodePath를 노드로 풀고 "하나라도 on" 판정.


static func resolve(owner: Node, paths: Array[NodePath]) -> Array[Node]:
	var nodes: Array[Node] = []
	for path: NodePath in paths:
		var source: Node = owner.get_node_or_null(path)
		if source == null or not "is_on" in source:
			push_warning("%s: 소스 %s를 찾을 수 없거나 is_on이 없다." % [owner.name, path])
			continue
		nodes.append(source)
	return nodes


static func any_on(sources: Array[Node]) -> bool:
	for source: Node in sources:
		if source.is_on:
			return true
	return false
