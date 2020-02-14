namespace Music2 {
    public class Views.SourceListRoot : Granite.Widgets.SourceList.ExpandableItem,
                                        Granite.Widgets.SourceListSortable {
        public SourceListRoot () {
            base ("SourceListRoot");
        }

        private bool allow_dnd_sorting () {
            return true;
        }

        private int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
            return 0;
        }
    }
}
