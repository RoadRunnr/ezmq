% Copyright 2010-2011, Travelping GmbH <info@travelping.com>

% Permission is hereby granted, free of charge, to any person obtaining a
% copy of this software and associated documentation files (the "Software"),
% to deal in the Software without restriction, including without limitation
% the rights to use, copy, modify, merge, publish, distribute, sublicense,
% and/or sell copies of the Software, and to permit persons to whom the
% Software is furnished to do so, subject to the following conditions:

% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.

% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
% DEALINGS IN THE SOFTWARE.

-module(gen_zmq_frame).

-export([decode/2, encode/1]).

-define(FLAG_NONE, 16#00).
-define(FLAG_MORE, 16#01).
-define(FLAG_LABEL, 16#80).

bool(0) -> false;
bool(1) -> true.

frame_type(0, 1) -> label;
frame_type(_, _) -> normal.
	

decode(Ver, Data = <<16#FF, Length:64/unsigned-integer, Flags:8/bits, Rest/binary>>) ->
	decode(Ver, Length - 1, Flags, Rest, Data);
decode(Ver, Data = <<Length:8/integer, Flags:8/bits, Rest/binary>>) ->
	decode(Ver, Length - 1, Flags, Rest, Data);
decode(_Ver, Data) ->
	{more, Data}.

decode(_Ver, FrameLen, _Flags, Msg, Data) when size(Msg) < FrameLen ->
	{more, Data};
decode(Ver, FrameLen, <<Label:1, _:6, More:1>>, Msg, _Data) ->
	<<Frame:FrameLen/bytes, Rem/binary>> = Msg,
	{{bool(More), {frame_type(Ver, Label), Frame}}, Rem}.

	

encode(Msg) when is_list(Msg) ->
	encode(Msg, []).

encode([], Acc) ->
	list_to_binary(lists:reverse(Acc));
encode([{label, Head}|Rest], Acc) ->
	encode(Head, ?FLAG_LABEL, Rest, Acc);
encode([{normal, Head}|Rest], Acc) when is_binary(Head); is_list(Head) ->
	encode(Head, ?FLAG_NONE, Rest, Acc);
encode([Head|Rest], Acc) when is_binary(Head); is_list(Head) ->
	encode(Head, ?FLAG_NONE, Rest, Acc).

encode(Frame, Flags, Rest, Acc) when is_list(Frame) ->
	encode(iolist_to_binary(Frame), Flags, Rest, Acc);
encode(Frame, Flags, Rest, Acc) when is_binary(Frame) ->
	Length = size(Frame) + 1,
	Header = if
				 Length >= 255 -> <<16#FF, Length:64>>;
				 true -> <<Length:8>>
			 end,
	Flags1 = if
				 length(Rest) =/= 0 -> Flags bor ?FLAG_MORE;
				 true -> Flags
			 end,
	encode(Rest, [<<Header/binary, Flags1:8, Frame/binary>>|Acc]).

