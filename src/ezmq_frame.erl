%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_frame).

-export([socket_type_atom/1, socket_type_int/1]).
-export([decode/2, encode/2]).
-export([decode_greeting/1, encode_greeting/3]).

socket_type_int(pair)  ->       16#00;
socket_type_int(pub)   ->       16#01;
socket_type_int(sub)   ->       16#02;
socket_type_int(req)   ->       16#03;
socket_type_int(rep)   ->       16#04;
socket_type_int(dealer) ->      16#05;
socket_type_int(router) ->      16#06;
socket_type_int(pull)   ->      16#07;
socket_type_int(push)   ->      16#08.

socket_type_atom(16#00) ->      pair;
socket_type_atom(16#01) ->      pub;
socket_type_atom(16#02) ->      sub;
socket_type_atom(16#03) ->      req;
socket_type_atom(16#04) ->      rep;
socket_type_atom(16#05) ->      dealer;
socket_type_atom(16#06) ->      router;
socket_type_atom(16#07) ->      pull;
socket_type_atom(16#08) ->      push.

bool(0) -> false;
bool(_) -> true.

bool2i(false) -> 0;
bool2i(true)  -> 1.

decode_greeting(Data = <<16#FF, IdLength:64, IdFlag:8/integer, Rest/binary>>) ->
    validate_greeting(long, IdLength, IdFlag, Rest, Data);
decode_greeting(Data = <<IdLength:8/integer, IdFlag:8/integer, Rest/binary>>) ->
    validate_greeting(short, IdLength, IdFlag, Rest, Data);
decode_greeting(Data) ->
    {more, Data}.

validate_greeting(short, IdLength, IdFlag, Rest, _Data)
  when IdLength > 0 andalso IdFlag band 16#01 == 0 ->
    {{short, IdLength - 1}, Rest};
validate_greeting(long, IdLength, 16#7F, Rest, _Data)
  when IdLength > 0 andalso IdLength < 256 ->
    {{long, IdLength - 1}, Rest};
validate_greeting(_FrameType, _IdLength, _IdFlag, _Rest, Data) ->
    {invalid, Data}.

decode({1,0}, Data = <<16#FF, Length:64/unsigned-integer, Flags:8/bits, Rest/binary>>) ->
    decode_13(Length, Flags, Rest, Data);
decode({1,0}, Data = <<Length:8/integer, Flags:8/bits, Rest/binary>>) ->
    decode_13(Length, Flags, Rest, Data);
decode({1,0}, Data) ->
    {more, Data};

%% short frame
decode({2,0}, Data = <<0:6, 0:1, More:1, Length:8/unsigned-integer, Rest/binary>>) ->
    decode_15(Length, More, Rest, Data);
%% long frame
decode({2,0}, Data = <<0:6, 1:1, More:1, Length:64/unsigned-integer, Rest/binary>>) ->
    decode_15(Length, More, Rest, Data);
decode({2,0}, Data = <<0:6, _:2, _/binary>>) ->
    {more, Data};

decode(_Ver, Data) ->
    {invalid, Data}.

decode_13(FrameLen, _Flags, _Msg, Data) when FrameLen =:= 0 ->
    {invalid, Data};
decode_13(FrameLen, _Flags, Msg, Data) when size(Msg) < FrameLen - 1->
    {more, Data};
decode_13(FrameLen, <<_:7, More:1>>, Msg, _Data) ->
    FLen = FrameLen - 1,
    <<Frame:FLen/bytes, Rem/binary>> = Msg,
    {{bool(More), {normal, Frame}}, Rem}.

decode_15(FrameLen, _More, Msg, Data) when size(Msg) < FrameLen ->
    {more, Data};
decode_15(FrameLen, More, Msg, _Data) ->
    <<Frame:FrameLen/bytes, Rest/binary>> = Msg,
    {{bool(More), {normal, Frame}}, Rest}.

encode_greeting({Major,_}, _SocketType, Identity)
  when Major > 1, is_binary(Identity), byte_size(Identity) =< 254 ->
    Length = byte_size(Identity) + 1,
    <<16#FF, Length:64, 16#7F>>;
encode_greeting({1,0}, _SocketType, Identity)
  when is_binary(Identity), byte_size(Identity) =< 254 ->
    Length = byte_size(Identity) + 1,
    <<Length:8, 16#00, Identity/binary>>;

encode_greeting(Version, SocketType, Identity) ->
    error(badarg, [Version, SocketType, Identity]).

encode(Version, Msg) when is_list(Msg) ->
    encode(Version, Msg, []).

encode(_, [], Acc) ->
    list_to_binary(lists:reverse(Acc));
encode(Version, [Head = {_, Data}|Rest], Acc) when is_binary(Data); is_list(Data) ->
    encode(Version, Rest, [encode_frame(Version, Head, length(Rest) =/= 0)|Acc]);
encode(_Version, [Head|_Rest], _Acc) ->
    error(badarg, [Head]).

encode_frame(Version, {Type, Data}, More) when is_list(Data) ->
    encode_frame(Version, Type, iolist_to_binary(Data), More);
encode_frame(Version, {Type, Data}, More) ->
    encode_frame(Version, Type, Data, More).

encode_frame({1, _}, normal, Data, More) ->
    Length = size(Data) + 1,
    Header = if
                 Length >= 255 -> <<16#FF, Length:64>>;
                 true -> <<Length:8>>
             end,
    <<Header/binary, 0:7, (bool2i(More)):1, Data/binary>>;

encode_frame({2, 0}, normal, Data, More) when size(Data) =< 255 ->
    Length = size(Data),
    <<0:6, 0:1, (bool2i(More)):1, Length:8, Data/binary>>;
encode_frame({2, 0}, normal, Data, More) ->
    Length = size(Data),
    <<0:6, 1:1, (bool2i(More)):1, Length:64, Data/binary>>;

encode_frame(Version, Type, Data, More) ->
    error(badarg, [Version, Type, Data, More]).
