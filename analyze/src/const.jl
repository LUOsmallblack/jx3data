using DataFrames, Spark

kungfu_cn_map = Dict(
    :xisui => ("洗髓", "洗"),
    :yijin => ("易经", "秃"),
    :zixia => ("紫霞", "气"),
    :taixu => ("太虚", "剑"),
    :huajian => ("花间", "花"),
    :aoxue => ("傲血", "策"),
    :lijing => ("离经", "离"),
    :tielao => ("铁牢", "铁"),
    :yunshang => ("云裳", "秀"),
    :bingxin => ("冰心", "冰"),
    :cangjian => ("藏剑", "藏"),
    :dujing => ("毒经", "毒"),
    :butian => ("补天", "补"),
    :jingyu => ("惊羽", "鲸"),
    :tianluo => ("天罗", "螺"),
    :fenying => ("焚影", "明"),
    :mingzun => ("明尊", "喵"),
    :xiaochen => ("笑尘", "丐"),
    :tiegu => ("铁骨", "骨"),
    :fenshan => ("分山", "苍"),
    :mowen => ("莫问", "莫"),
    :xiangzhi => ("相知", "歌"),
    :beiao => ("北傲", "霸"))
kungfu_cn_df = DataFrame(vcat([[i v1 v2] for (i, (v1, v2)) in kungfu_cn_map]...), [:content, :kungfu, :short])

using JavaCall

JArrays = @jimport java.util.Arrays
JList = @jimport java.util.List
JEncoders = @jimport org.apache.spark.sql.Encoders
JEncoder = @jimport org.apache.spark.sql.Encoder

function df2spark(sess::SparkSession, df::DataFrame)
    json = dump_json(df)
    list = jdcall(JArrays, "asList", json)
    encoder = jdcall(JEncoders, "STRING")
    jds = jcall(sess.jsess, "createDataset", Spark.JDataset, (JList, JEncoder), list, encoder)
    jdf = jcall(Spark.dataframe_reader(sess), "json", Spark.JDataset, (Spark.JDataset,), jds)
    return Dataset(jdf)
end

#%%
kungfu_order = [
    :taixu,
    :zixia, :bingxin, :fenying, :yijin, :huajian, :dujing, :tianluo, :mowen,
    :aoxue, :fenshan, :cangjian, :jingyu, :xiaochen, :beiao,
    :xisui, :tielao, :tiegu, :mingzun,
    :lijing, :yunshang, :butian, :xiangzhi]
kungfu_order_sp = Set([(:jingyu, :tianluo)])
kungfu_order_map = Dict([(v,i) for (i,v) in enumerate(kungfu_order)])
function kungfu_isless(x, y)
    if (x, y) ∈ kungfu_order_sp
        true
    elseif (y, x) ∈ kungfu_order_sp
        false
    else
        kungfu_order_map[x] < kungfu_order_map[y]
    end
end

init_const(spark, items) = global kungfu_items = init_kungfu_items(spark, items)

show_kungfus(xs) = join(sort(kungfu_items[[findfirst(x .== kungfu_items[:id]) for x in xs],:], :content; lt=kungfu_isless)[:short])
