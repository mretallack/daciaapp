inputText .emptyText {
    fontSize: (attributes.fontSize ?? @unset);
}

inputText {
    text:( value );
    color:( attributes.color );
}

sprite#pasteButtonBg {
    position: @absolute;
    img: const({ borderWidth: 1, borderRadius: 5, borderImg:( #585858 ), img:( #fff ) });
    boxShadow: ( 0, 0, 8, 6, #B8B8B8, @shallow );
}

text#pasteButtonText {
    paddingLeft: 10;
    paddingRight: 10;
    paddingBottom: 5;
    paddingTop: 5;
}
