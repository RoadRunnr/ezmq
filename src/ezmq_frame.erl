%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_frame).

-export([decode/2, encode/1]).
-export([decode_greeting/1, encode_greeting/3]).

-define(FLAG_NONE, 16#00).
-define(FLAG_MORE, 16#01).
-define(FLAG_LABEL, 16#80).

bool(0) -> false;
bool(1) -> true.

frame_type(0, 1) -> label;
frame_type(_, _) -> normal.

%% ZeroMQ RFC 13 says IDFlags should be 0x00 in the greeting, however the actuall
%% libzmq2 implementation send 0x7E, so only insist on the LSB beeing zero

decode_greeting(Data = <<16#FF, Length:64/unsigned-integer, _:7, IDFlags:1/integer, Rest/binary>>) ->
    decode_greeting({1,0}, Length, IDFlags, Rest, Data);
decode_greeting(Data = <<Length:8/integer, _:7, IDFlags:1/integer, Rest/binary>>) ->
    decode_greeting({1,0}, Length, IDFlags, Rest, Data);
decode_greeting(Data) ->
    {more, Data}.

decode_greeting({1,0}, FrameLen, 0, Msg, Data) when size(Msg) < FrameLen - 1->
    {more, Data};
decode_greeting(Ver = {1,0}, FrameLen, 0, Msg, _Data) ->
    IDLen = FrameLen - 1,
    <<Identity:IDLen/bytes, Rem/binary>> = Msg,
    {{greeting, Ver, undefined, Identity}, Rem};
decode_greeting({1,0}, FrameLen, _IDFlags, Msg, _Data) ->
    IDLen = FrameLen - 1,
    <<_:IDLen/bytes, Rem/binary>> = Msg,
    {invalid, Rem}.

decode(Ver, Data = <<16#FF, Length:64/unsigned-integer, Flags:8/bits, Rest/binary>>) ->
    decode(Ver, Length, Flags, Rest, Data);
decode(Ver, Data = <<Length:8/integer, Flags:8/bits, Rest/binary>>) ->
    decode(Ver, Length, Flags, Rest, Data);
decode(_Ver, Data) ->
    {more, Data}.

decode(_Ver, FrameLen, _Flags, _Msg, Data) when FrameLen =:= 0 ->
    {invalid, Data};
decode(_Ver, FrameLen, _Flags, Msg, Data) when size(Msg) < FrameLen - 1->
    {more, Data};
decode(Ver, FrameLen, <<Label:1, _:6, More:1>>, Msg, _Data) ->
    FLen = FrameLen - 1,
    <<Frame:FLen/bytes, Rem/binary>> = Msg,
    {{bool(More), {frame_type(Ver, Label), Frame}}, Rem}.

encode_greeting({1,0}, _SocketType, Identity)
  when is_binary(Identity) ->
    encode(Identity, ?FLAG_NONE, [], []).

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

