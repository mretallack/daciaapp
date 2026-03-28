import { Map } from "system://core.types"

export decorator @restorePos() {
    @register(listView => {
        // todo: how will we get the associated controller?, or the current state in the controller
        //      ocurrently we traverse listView parents, until we get a valid controller property (the fragment/group  or window instantiating listView's fragment)
        
        let target = listView.parent;
        for (;target; target = target.parent) {
            if (target.controller) {
                target.controller.current.restoreList(listView);
                break;
            }
        }
    })
}

export class ListRestorer {
	#listView;
	firstItem = 0;
	firstItemOffset = 0;

	get listView() { this.#listView }
	set listView(lv) { this.#listView = weak(lv) }

	constructor(listView) {
		this.#listView = weak(listView);
		// NOTE: maybe could register to destroy listener of listView to save pos. is this too late?
	}

	savePos() {
		if (!this.#listView) return;
		this.firstItem = this.#listView.firstItem;
		this.firstItemOffset = this.#listView.firstItemOffset;
	}

	restorePos(listView) {
		this.listView = listView;
		listView.showItem(this.firstItem, this.firstItemOffset);
	}
}

export state st_ListRestorerHolder {
	restoreList(listView) {
		this.restorers = this.restorers ?? new Map; // create restorers prop on demand
		const defId = listView.definitionId;
		const listRestorer = this.restorers.get(defId) ?? new ListRestorer(listView);
		const insert = listRestorer.listView == listView; // freshly created
		if (!insert) 
			listRestorer.restorePos(listView);
		 else this.restorers.set(defId, listRestorer);
	}

	done(ctrl) {
		for (const rest in this.restorers.values) {
			rest.savePos();
		}
	}
}
