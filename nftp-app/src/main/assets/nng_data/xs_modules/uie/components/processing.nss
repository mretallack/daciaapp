processing {
	position: @absolute;
	valign: @bottom;
}

processing >>> sprite.processing{
	transition: ([
		( @alpha, ( attributes.fadeTime ), @easeInOut, @quad ),
		( @left, ( attributes.animTime/3 ), @linear ),
		( @imageW, ( attributes.animTime/3 ), @linear ),
		( @imageH, ( attributes.animTime/3 ), @linear )
	]);
	img: ({ borderRadius: ( attributes.minHeight ), img: ( attributes.processColor )});
}

processing >>> sprite.processing.fadeIn{
	alpha: 32;
}

processing >>> sprite.processing.fadeOut{
	alpha: 0;
}

processing >>> sprite.processing.firstPhase {
	imageW: ( this.parent.parent.w/3 );
	imageH: ( attributes.maxHeight );
	left: ( this.parent.parent.w/3 );
}

processing >>> sprite.processing.secondPhase {
	imageW: ( attributes.minWidth );
	imageH: ( attributes.minHeight );
	left: ( this.parent.parent.w - attributes.padding - attributes.minWidth  );
}

processing >>> sprite.processing.thirdPhase {
	imageW: ( attributes.minWidth  );
	imageH: ( attributes.minHeight );
	left: ( attributes.padding );
}

processing >>> sprite.processing.noPhase{
	imageW: ( attributes.minWidth  );
	imageH: ( attributes.minHeight );
	left: ( attributes.padding );
}

//----------- dots -----------

component#processingDots{
	boxAlign: @stretch;
}

sprite.processingDot{
	img: ({
		borderRadius: ( attributes.dotSize / 2 ),
		img: (attributes.dotColor) });
	valign: @center;
	imageW: (attributes.dotSize);
	imageH: (attributes.dotSize);
	flex: 1;
	transition: ( @opacity, attributes.animTime, @linear, attributes.delay*index );

}


