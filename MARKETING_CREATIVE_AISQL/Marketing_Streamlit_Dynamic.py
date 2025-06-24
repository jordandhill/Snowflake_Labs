import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col
from io import BytesIO

# ---------- Page Setup ---------- #
st.set_page_config(
    page_title="Creative Approvals",
    page_icon="🎨",
    layout="wide",
)

st.title("🎨 Marketing Creative Review - Dynamic")

# ---------- Snowflake Session & Data ---------- #
session = get_active_session()


# ---------- Custom CSS ---------- #
st.markdown(
    """
    <style>
        .card {
            box-shadow: 0 4px 8px rgba(0,0,0,.08);
            border-radius: 12px;
            padding: 1rem 1.2rem;
            margin-bottom: 1.5rem;
            background-color: var(--secondary-background-color);
        }
        .card img { border-radius: 8px; }
        .stButton button {
            border-radius: 6px;
            font-weight: 600;
            padding: 0.4rem 1rem;
        }
    </style>
    """,
    unsafe_allow_html=True,
)

rules = st.text_input("Type image rules below", "Image Contains a Flamingo")

sql_text = "SELECT img_file, file_url, 'Needs Review' AS STATUS FROM creative_image_review WHERE AI_FILTER('"+rules+"',img_file)"

df = session.sql(sql_text).to_pandas()

images = []
for url in df["FILE_URL"]:
    # Get raw bytes for each image stored in the stage
    images.append(session.file.get_stream(url, decompress=False).read())
df["IMAGE_BYTES"] = images

#st.dataframe(df)

# ---------- UI Loop ---------- #
for _, row in df.iterrows():
    with st.container():
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        cols = st.columns([2, 3, 1])

        # Image preview
        with cols[0]:
            st.image(row.IMAGE_BYTES, width=250)

        # Metadata & status
        with cols[1]:
            st.subheader(f"**Violation:** {row.STATUS}")

        # Approval action
        with cols[2]:
            if row.STATUS is not None: 
                if st.button("Approve ✅", key=f"approve-{row.FILE_URL}"):
                    session.sql(
                    """
                    UPDATE CREATIVE_IMAGE_REVIEW
                    SET STATUS = 'Approved (manual)'
                    WHERE FILE_URL = :url
                    """,
                    params={"url": row.FILE_URL},
                    ).collect()
                    st.toast("Marked as approved!", icon="✅")


        st.markdown("</div>", unsafe_allow_html=True)
